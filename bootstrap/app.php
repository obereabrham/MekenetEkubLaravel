<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use App\Http\Middleware\AuthenticateSession;
use App\Http\Middleware\EnsureActiveMember;
use App\Http\Middleware\RequireRole;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up'
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'auth.session' => AuthenticateSession::class,
            'role' => RequireRole::class,
            'member.api' => EnsureActiveMember::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {})
    ->create();
