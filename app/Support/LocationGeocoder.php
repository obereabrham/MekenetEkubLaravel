<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

class LocationGeocoder
{
    /** Resolve a submitted business location and cache successful results. */
    public function geocode(string $location): ?array
    {
        $location = trim(preg_replace('/\s+/u', ' ', $location) ?? '');
        if (mb_strlen($location) < 3) return null;

        $cacheKey = 'merchant-location:'.hash('sha256', mb_strtolower($location));

        return Cache::remember($cacheKey, now()->addDays(30), function () use ($location): ?array {
            try {
                return Cache::lock('nominatim-global-request', 20)->block(10, function () use ($location): ?array {
                    $lastRequest = (float) Cache::get('nominatim-last-request-at', 0);
                    $wait = 1.05 - (microtime(true) - $lastRequest);
                    if ($wait > 0) usleep((int) ($wait * 1_000_000));
                    Cache::put('nominatim-last-request-at', microtime(true), now()->addMinutes(5));

                    $response = Http::withUserAgent('MekenetEkub/1.0 ('.config('app.url').')')
                        ->acceptJson()
                        ->timeout(8)
                        ->get(config('services.map_geocoder.search_url'), [
                            'q' => $location,
                            'format' => 'jsonv2',
                            'limit' => 1,
                            'countrycodes' => 'et',
                        ]);

                    if (! $response->successful()) return null;
                    $result = $response->json('0');
                    if (! is_array($result) || ! is_numeric($result['lat'] ?? null) || ! is_numeric($result['lon'] ?? null)) return null;

                    return [
                        'latitude' => (float) $result['lat'],
                        'longitude' => (float) $result['lon'],
                        'display_name' => (string) ($result['display_name'] ?? $location),
                    ];
                });
            } catch (Throwable $exception) {
                Log::notice('Merchant location lookup failed.', ['exception' => $exception::class]);
                return null;
            }
        });
    }
}
