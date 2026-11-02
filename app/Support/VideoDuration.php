<?php

namespace App\Support;

use Illuminate\Http\UploadedFile;
use RuntimeException;
use Symfony\Component\Process\ExecutableFinder;
use Symfony\Component\Process\Process;

class VideoDuration
{
    public static function assertAgreementLength(UploadedFile $video): void
    {
        $ffprobe = (new ExecutableFinder())->find('ffprobe');
        if (! $ffprobe) return; // Local development can rely on the in-app recorder; Docker installs ffprobe.
        $process = new Process([$ffprobe, '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', $video->getRealPath()]);
        $process->setTimeout(12);
        $process->run();
        $duration = $process->isSuccessful() ? (float) trim($process->getOutput()) : 0.0;
        if ($duration < 5.0 || $duration > 10.5) {
            throw new RuntimeException('Agreement video must be at least 5 seconds and no longer than 10 seconds. Record it in the app and try again.');
        }
    }
}
