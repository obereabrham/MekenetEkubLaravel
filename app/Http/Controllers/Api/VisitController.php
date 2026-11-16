<?php

namespace App\Http\Controllers\Api;

use App\Support\VisitTracker;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Throwable;

class VisitController
{
    public function record(Request $request)
    {
        try {
            $user = Auth::guard('sanctum')->user();
            app(VisitTracker::class)->record($request, 'app', $user ? (int) $user->id : null);
        } catch (Throwable $e) {
            report($e);
        }

        return response()->json(['recorded' => true]);
    }
}
