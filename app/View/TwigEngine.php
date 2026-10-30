<?php
namespace App\View;

use App\Support\LegacyBag;
use Illuminate\Contracts\View\Engine;
use Twig\Environment;

class TwigEngine implements Engine
{
    public function __construct(private Environment $twig) {}
    public function get($path, array $data = []): string
    {
        $data['request'] = (object) [
            'args' => new LegacyBag(request()->query()),
            'form' => new LegacyBag(request()->all()),
        ];
        return $this->twig->render(basename($path), $data);
    }
}
