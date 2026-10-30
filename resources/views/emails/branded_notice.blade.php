<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ $headline }}</title>
</head>
<body style="margin:0;background:#f2f7f5;font-family:Arial,Helvetica,sans-serif;color:#182822">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:28px 12px;background:#f2f7f5">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fff;border:1px solid #e1ece8;border-radius:22px;overflow:hidden">
        <tr><td style="height:8px;background:linear-gradient(90deg,#88b44a,#43b5d4)"></td></tr>
        <tr><td style="padding:22px 28px 10px">
          <table role="presentation" cellspacing="0" cellpadding="0" align="center"><tr>
            <td valign="middle" style="padding:5px;background:#f0f7e9;border:1px solid #deebd0;border-radius:50%">
              <img src="{{ $message->embed(public_path('static/images/mekenet-ekub-logo.png')) }}" width="38" height="38" alt="Mekenet Ekub logo" style="display:block;width:38px;height:38px;object-fit:contain;border-radius:50%">
            </td>
            <td valign="middle" style="padding-left:10px">
              <div style="color:#182822;font-size:15px;font-weight:800;letter-spacing:.3px">Mekenet Ekub</div>
              <div style="padding-top:3px;color:#718078;font-size:10px;font-weight:700;letter-spacing:1.1px">BUILD YOUR FUTURE TOGETHER</div>
            </td>
          </tr></table>
        </td></tr>
        <tr><td style="padding:12px 32px 30px">
          <h1 style="margin:0 0 14px;text-align:center;font-size:25px;line-height:1.25;color:#182822">{{ $headline }}</h1>
          @if($code)
            <div style="margin:22px auto;padding:17px 12px;max-width:350px;border:1px solid #dcebe4;border-radius:16px;background:#f4faf7;text-align:center;color:#168653;font-family:Consolas,monospace;font-size:32px;font-weight:800;letter-spacing:10px">{{ $code }}</div>
          @endif
          <div style="font-size:16px;line-height:1.7;color:#52635c">{!! nl2br(e($body)) !!}</div>
          @if(!empty($details))
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-top:20px;border:1px solid #e1ece8;border-radius:14px;background:#f8fbf9">
              <tr><td colspan="2" style="padding:14px 16px 6px;color:#182822;font-size:15px;font-weight:800">Ekub information</td></tr>
              @foreach($details as $detail)
                <tr>
                  <td valign="top" style="padding:7px 8px 7px 16px;color:#75847c;font-size:13px">{{ $detail['label'] }}</td>
                  <td valign="top" align="right" style="padding:7px 16px 7px 8px;color:#273b32;font-size:13px;font-weight:700">{{ $detail['value'] }}</td>
                </tr>
              @endforeach
            </table>
          @endif
          @if(!empty($rules))
            <div style="margin-top:16px;padding:15px 16px;border:1px solid #dcebe4;border-radius:14px;background:#f4faf7">
              <div style="margin-bottom:8px;color:#182822;font-size:15px;font-weight:800">Participation rules</div>
              @foreach($rules as $rule)
                <div style="padding:4px 0;color:#52635c;font-size:13px;line-height:1.55">&#8226;&nbsp; {{ $rule }}</div>
              @endforeach
            </div>
          @endif
          <div style="height:1px;margin:26px 0 16px;background:#e8efec"></div>
          <p style="margin:0;text-align:center;color:#87958e;font-size:12px;line-height:1.6">Mekenet Ekub · Build your future together</p>
          <p style="margin:6px 0 0;text-align:center;color:#a1ada7;font-size:11px;line-height:1.5">@if($code)This is an automated security message. Never share this verification code with anyone.@else This is an automated Mekenet Ekub account message.@endif</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
