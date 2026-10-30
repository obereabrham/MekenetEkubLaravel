<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['username' => env('ADMIN_USERNAME', 'obere19')],
            [
                'first_name' => env('ADMIN_FIRST_NAME', 'Abrham'),
                'last_name' => env('ADMIN_LAST_NAME', 'Tesfaye'),
                'phone' => env('ADMIN_PHONE', '0951180317'),
                'password' => Hash::make(env('ADMIN_PASSWORD', '19@Abrish_@21')),
                'role' => 'admin',
            ]
        );
    }
}
