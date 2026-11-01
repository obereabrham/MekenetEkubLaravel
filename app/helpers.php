<?php

if (! function_exists('route_url')) {
    function route_url(string $endpoint, array $params = []): string
    {
        $paths = [
            'home'=>'/','home_page'=>'/home','about'=>'/about','contact'=>'/contact','terms'=>'/terms','privacy'=>'/privacy','ekubs'=>'/ekubs',
            'ekub_detail'=>'/ekub/{ekub_id}','register'=>'/register','login'=>'/login','verify_login'=>'/verify-login','security_2fa'=>'/security/2fa','confirm_2fa'=>'/security/2fa/confirm','logout'=>'/logout',
            'dashboard'=>'/dashboard','dashboard_stats_api'=>'/api/dashboard/stats','profile'=>'/profile','profile_edit'=>'/profile/edit/{field}','profile_picture_update'=>'/profile/picture','kyc'=>'/kyc',
            'join_ekub'=>'/join/{ekub_id}','join_ekub_legacy'=>'/join-ekub','my_ekubs'=>'/my-ekubs','leave_ekub'=>'/leave-ekub/{ekub_id}','status'=>'/status','my_status'=>'/my-status','pay'=>'/pay/{ekub_id}/{period_no}',
            'admin_login'=>'/admin/login','admin_dashboard'=>'/admin/dashboard','admin_full_ekubs'=>'/admin/full-ekubs','admin_pick_winners'=>'/admin/pick-winners','create_ekub'=>'/admin/ekubs/create','admin_edit_ekub'=>'/admin/ekubs/{ekub_id}/edit','admin_delete_ekub'=>'/admin/ekubs/{ekub_id}/delete','admin_ekub_information'=>'/admin/ekubs/{ekub_id}/information','start_ekub'=>'/admin/ekubs/{ekub_id}/start',
            'admin_payment_status'=>'/admin/payment-status','admin_payment_status_detail'=>'/admin/payment-status/{ekub_id}','admin_send_payment_reminder'=>'/admin/payment-status/{ekub_id}/remind',
            'admin_payment_approval'=>'/admin/payment-approval','admin_payment_approval_ekub'=>'/admin/payment-approval/ekub/{ekub_id}','admin_payment_approval_all'=>'/admin/payment-approval-all','admin_payments'=>'/admin/payments/{ekub_id}/{period_no}','payment_action'=>'/admin/payment/{payment_id}/{action}',
            'admin_kyc'=>'/admin/kyc','kyc_action'=>'/admin/kyc/{kyc_id}/{action}','admin_members'=>'/admin/members','payment_methods'=>'/payment-methods','payment_method_delete'=>'/payment-methods/{pm_id}/delete','payment_method_default'=>'/payment-methods/{pm_id}/default',
            'settings'=>'/settings','send_security_code'=>'/settings/security-code','change_username'=>'/settings/username','change_password'=>'/settings/password','delete_account'=>'/settings/delete-account','admin_deleted_accounts'=>'/admin/deleted-accounts','admin_suspend_members'=>'/admin/suspend','member_suspend_action'=>'/admin/members/{user_id}/{action}',
            'partners'=>'/admin/partners','delete_partner'=>'/admin/partners/{pid}/delete','partner_login'=>'/partner/login','partner_dashboard'=>'/partner','partner_payment_approval'=>'/partner/payment-approval','partner_payment_approval_ekub'=>'/partner/payment-approval/ekub/{ekub_id}','partner_payment_approval_all'=>'/partner/payment-approval-all','partner_members'=>'/partner/members','partner_kyc'=>'/partner/kyc','partner_payment'=>'/partner/payment/{ekub_id}/{period_no}',
            'pick_winner'=>'/admin/winners/{ekub_id}/{period_no}','recent_winners'=>'/admin/recent-winners','recent_winner_send'=>'/recent-winners/{payout_id}/send','admin_ads'=>'/admin/ads','admin_ad_save'=>'/admin/ads/{slot}','admin_ad_delete'=>'/admin/ads/{slot}/delete',
            'finished_ekubs'=>'/finished-ekubs','apply_ekub'=>'/apply-ekub','admin_applied_ekubs'=>'/admin/applied-ekubs','admin_approve_application'=>'/admin/applied-ekubs/{app_id}/approve','admin_reject_application'=>'/admin/applied-ekubs/{app_id}/reject','uploads'=>'/uploads/{name}',
        ];
        if ($endpoint === 'static') {
            $filename = ltrim((string) ($params['filename'] ?? ''), '/');
            if (str_starts_with($filename, 'uploads/')) {
                return route_url('uploads', ['name' => substr($filename, strlen('uploads/'))]);
            }
            return asset('static/'.$filename);
        }
        $path = $paths[$endpoint] ?? '/';
        foreach ($params as $key => $value) {
            $placeholder = '{'.$key.'}';
            if (str_contains($path, $placeholder)) {
                $encoded = $key === 'name' ? implode('/', array_map('rawurlencode', explode('/', ltrim((string) $value, '/')))) : rawurlencode((string) $value);
                $path = str_replace($placeholder, $encoded, $path);
                unset($params[$key]);
            }
        }
        $query = array_filter($params, static fn ($value) => $value !== null);
        return $path.($query ? '?'.http_build_query($query) : '');
    }
}
