<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        $token = $user?->currentAccessToken();

        if (! $user || $user->role !== 'admin' || $user->status !== 'active' || ! $token || ! $token->can('admin')) {
            return response()->json(['message' => 'An active admin session is required.'], 403);
        }

        return $next($request);
    }
}
