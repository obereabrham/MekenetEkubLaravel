<?php

return [
    // Keep the local public disk as the development default. Set UPLOADS_DISK=r2 on Render.
    'disk' => env('UPLOADS_DISK', 'public'),
];
