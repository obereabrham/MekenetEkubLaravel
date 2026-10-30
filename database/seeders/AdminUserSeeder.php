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
            ['username' => 'obere19'], // በ Render Environment Variables ላይ ያስቀመጥከው ዩዘር ስም
            [
                'first_name' => 'Admin',
                'last_name' => 'User',
                'phone' => '19Abrish_@21', // ተስማሚ ስልክ ቁጥር ወይም ፎርማት
                'password' => Hash::make('19Abrish_@21'), // የይለፍ ቃልህ
                'role' => 'admin', // ሮሉ አድሚን መሆኑን ለማረጋገጥ
            ]
        );
    }
}
