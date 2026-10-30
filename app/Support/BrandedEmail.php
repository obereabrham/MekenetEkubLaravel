<?php

namespace App\Support;

use Illuminate\Support\Facades\Mail;

final class BrandedEmail
{
    public static function send(
        string $to,
        string $subject,
        string $headline,
        string $body,
        ?string $code = null,
        array $details = [],
        array $rules = [],
    ): void
    {
        Mail::send('emails.branded_notice', [
            'headline' => $headline,
            'body' => $body,
            'code' => $code,
            'details' => $details,
            'rules' => $rules,
        ], function ($message) use ($to, $subject): void {
            $message->to($to)->subject($subject);
        });
    }
}
