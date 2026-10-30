<?php
namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $username = trim((string) env('ADMIN_USERNAME'));
        $password = (string) env('ADMIN_PASSWORD');
        $phone = trim((string) env('ADMIN_PHONE'));
        if ($username === '' || $password === '' || $phone === '') return;
        if (DB::table('users')->where('role', 'admin')->exists()) return;
        DB::table('users')->insert([
            'first_name' => env('ADMIN_FIRST_NAME', 'Site'), 'last_name' => env('ADMIN_LAST_NAME', 'Administrator'),
            'username' => $username, 'phone' => $phone, 'email' => env('ADMIN_EMAIL') ?: null,
            'password_hash' => Hash::make($password), 'role' => 'admin', 'status' => 'active', 'kyc_status' => 'approved',
            'first_login' => 1, 'twofa_method' => 'authenticator', 'twofa_enabled' => 0, 'created_at' => now(),
        ]);
    }
}
