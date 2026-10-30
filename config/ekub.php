<?php
return [
    'categories' => ['Student','Merkato Merchants','Teachers',"Driver's",'Government Employees',"Item's Ekub"],
    'frequencies' => ['Daily','Weekly','Monthly'],
    'methods' => ['Telebirr','CBE','Binance Pay'],
    'banks' => ['Commercial Bank of Ethiopia (CBE)','Telebirr','Awash Bank','Bank of Abyssinia','Dashen Bank','Wegagen Bank','Hibret Bank','Nib International Bank','Cooperative Bank of Oromia','Oromia Bank','Zemen Bank','Bunna Bank','Berhan Bank','Abay Bank','Addis International Bank','Enat Bank','Lion International Bank','Global Bank Ethiopia','Siinqee Bank','Tsehay Bank','Amhara Bank','Ahadu Bank','Gadaa Bank','Hijra Bank','ZamZam Bank','Shabelle Bank','Goh Betoch Bank','M-Pesa (Safaricom)'],
    'delete_reasons' => ['I no longer need the service','I have privacy concerns','I created a second account','I am not satisfied with the service','I had a problem with a payment','Other'],
    'payment_account_holder' => env('PAYMENT_ACCOUNT_HOLDER', ''),
    'payment_accounts' => ['Telebirr'=>env('PAYMENT_ACCOUNT_TELEBIRR',''),'CBE'=>env('PAYMENT_ACCOUNT_CBE',''),'Binance Pay'=>env('PAYMENT_ACCOUNT_BINANCE','')],
    'binance_etb_per_usdt' => (float) env('PAYMENT_BINANCE_ETB_PER_USDT', 0),
    'upload_extensions' => ['png','jpg','jpeg','webp','gif','mp4','mov','webm','pdf'],
];
