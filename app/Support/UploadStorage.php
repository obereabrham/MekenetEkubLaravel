<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use RuntimeException;

class UploadStorage
{
    public function diskName(): string
    {
        return (string) config('uploads.disk', 'public');
    }

    public function put(UploadedFile $file, string $path): string
    {
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension() ?: '');
        $imageExtensions = ['avif', 'bmp', 'gif', 'heic', 'heif', 'jpeg', 'jpg', 'png', 'svg', 'tif', 'tiff', 'webp'];
        $isImage = str_starts_with(strtolower((string) $file->getMimeType()), 'image/') || in_array($extension, $imageExtensions, true);
        if ($isImage && $file->getSize() > 1024 * 1024) {
            throw new RuntimeException('Images must be 1 MB or smaller.');
        }

        $path = $this->normalizePath($path);
        $directory = dirname($path);
        $stored = Storage::disk($this->diskName())->putFileAs(
            $directory === '.' ? '' : $directory,
            $file,
            basename($path),
            ['visibility' => 'private'],
        );

        if (! $stored) {
            throw new RuntimeException('Could not save the uploaded file. Check the configured upload storage.');
        }

        return $path;
    }

    public function userPath(string $username, int $userId, string $folder, string $filename): string
    {
        $username = mb_strtolower(trim($username));
        $username = preg_replace('/[^\pL\pN._-]+/u', '-', $username) ?? '';
        $username = trim(mb_substr($username, 0, 64), '.-_');
        $username = $username !== '' ? $username : 'member';
        $folder = self::normalizePath($folder);
        $filename = basename(str_replace('\\', '/', $filename));

        return self::normalizePath('users/'.$username.'-u'.$userId.'/'.$folder.'/'.$filename);
    }

    public function putForUser(UploadedFile $file, string $username, int $userId, string $folder, string $filename): string
    {
        return $this->put($file, $this->userPath($username, $userId, $folder, $filename));
    }

    public function exists(string $path): bool
    {
        $path = $this->normalizePath($path);

        if (Storage::disk($this->diskName())->exists($path)) {
            return true;
        }

        return is_file($this->legacyLocalPath($path));
    }

    public function delete(?string $path): void
    {
        if (! $path) return;

        $path = $this->normalizePath($path);
        $disk = Storage::disk($this->diskName());
        if ($disk->exists($path)) $disk->delete($path);

        $legacyPath = $this->legacyLocalPath($path);
        if (is_file($legacyPath)) @unlink($legacyPath);
    }

    public function url(string $path): string
    {
        $path = $this->normalizePath($path);

        if (self::isPrivatePath($path)) {
            return URL::temporarySignedRoute('uploads', now()->addMinutes(15), ['name' => $path]);
        }

        return route('uploads', ['name' => $path]);
    }

    public static function isPrivatePath(string $path): bool
    {
        $path = ltrim(str_replace('\\', '/', $path), '/');
        $segments = explode('/', $path);
        $first = strtolower($segments[0] ?? '');
        if (in_array($first, ['ads', 'ekub_items', 'profile'], true)) return false;
        if ($first === 'static' && strtolower($segments[1] ?? '') === 'uploads' && in_array(strtolower($segments[2] ?? ''), ['ads', 'ekub_items', 'profile'], true)) return false;
        if ($first === 'users' && in_array(strtolower($segments[2] ?? ''), ['ads', 'ekub_items', 'profile'], true)) return false;

        // Older website profile uploads were stored at the uploads root.
        if (! str_contains($path, '/') && preg_match('/\.(png|jpe?g|webp|gif)$/i', $path) && ! str_starts_with(strtolower($path), 'payment-')) {
            return false;
        }

        return true;
    }

    public static function normalizePath(string $path): string
    {
        $path = trim(str_replace('\\', '/', $path), '/');
        if ($path === '' || str_contains($path, "\0") || preg_match('/[^\pL\pN._\/-]/u', $path)) {
            throw new RuntimeException('Invalid upload path.');
        }

        foreach (explode('/', $path) as $segment) {
            if ($segment === '' || $segment === '.' || $segment === '..') {
                throw new RuntimeException('Invalid upload path.');
            }
        }

        return $path;
    }

    private function legacyLocalPath(string $path): string
    {
        return public_path('static/uploads/'.$path);
    }
}
