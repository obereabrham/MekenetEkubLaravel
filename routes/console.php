<?php
use Illuminate\Support\Facades\Artisan;
Artisan::command('about:ekub', function () { $this->line('Mekenet Ekub runs on Laravel and MySQL.'); })->purpose('Show the Mekenet Ekub application identity');