<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveMember
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || $user->role !== 'member' || $user->status !== 'active') {
            $user?->currentAccessToken()?->delete();

            return response()->json([
                'message' => 'This member account is not active.',
            ], 403);
        }

        return $next($request);
    }
}
