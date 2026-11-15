import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material;

String mekenetLanguageCode = 'EN';

void setMekenetLanguage(String code) {
  mekenetLanguageCode = const {'AM', 'ORO', 'EN'}.contains(code) ? code : 'EN';
}

const Map<String, String> _amharicTranslations = {
  'Total': 'ጠቅላላ',
  'Left': 'የቀረ',
  'Home': 'መነሻ',
  'Dashboard': 'ዳሽቦርድ',
  'MEKENET EKUB': 'መቀነት እቁብ',
  'BUILD YOUR FUTURE TOGETHER': 'ነገህን በጋራ እንገንባ',
  'Explore Ekubs and grow with your community.':
      'እቁቦችን ያስሱ፤ ከማህበረሰብዎ ጋርም አብረው ይደጉ።',
  'Your joined Ekubs': 'የተቀላቀሏቸው እቁቦች',
  'Ekubs': 'እቁቦች',
  'Available Ekubs': 'የሚገኙ እቁቦች',
  'Explore Ekubs by Category': 'እቁቦችን በምድብ ያስሱ',
  'My Ekubs': 'እቁቦቼ',
  'View all': 'ሁሉንም ይመልከቱ',
  'Top hosted Ekubs': 'ከፍተኛ የተስተናገዱ እቁቦች',
  'Item Ekubs': 'የዕቃዎች እቁቦች',
  'There are no open Ekubs right now. Pull down to refresh.':
      'በአሁኑ ጊዜ ክፍት እቁቦች የሉም። ለማደስ ወደ ታች ይጎትቱ።',
  'Your next step starts here': 'ቀጣዩ እርምጃዎ እዚህ ይጀምራል',
  'Start an Ekub or find one that fits your goals.':
      'እቁብ ይጀምሩ ወይም ከግቦችዎ ጋር የሚስማማ እቁብ ይፈልጉ።',
  'Create an Ekub': 'እቁብ አቋቁም',
  'Ekub': 'እቁብ',
  'Your activity': 'የእርስዎ እንቅስቃሴ',
  'Due now': 'አሁን መከፈል ያለበት',
  'Due': 'የሚከፈል',
  'Pending': 'በሂደት ላይ',
  'Paid': 'የተከፈለ',
  'Remaining': 'የቀረ',
  'Payment': 'ክፍያ',
  'In review': 'በግምገማ ላይ',
  'Upcoming': 'የሚመጣ',
  'Periods ready': 'ዝግጁ ዙር',
  'No payment submitted for this period yet.':
      'ለዚህ ዙር እስካሁን ምንም ክፍያ አልቀረበም።',
  'Group status': 'የቡድን ሁኔታ',
  'Current period': 'የአሁኑ ዙር',
  'Started': 'ተጀምሯል',
  'Open': 'ክፈት',
  'YOUR EKUB CONTRIBUTIONS': 'የእርሶ እቁብ መዋጮዎችዎ',
  'Stay on track': 'በመንገድ ላይ ይቆዩ',
  'Pay only the period shown below': 'ከዚህ በታች ለተመለከተው ዙር ብቻ ይክፈሉ',
  '1 period is ready for payment': 'ዙር 1 ለክፍያ ዝግጁ ነው',
  'Payment schedule': 'የክፍያ መርሐ ግብር',
  'Period Progress': 'የዙር ሂደት',
  'Pending review': 'በግምገማ ላይ',
  'Identity': 'ማንነት',
  'Payment Status': 'የክፍያ ሁኔታ',
  'Choose an Ekub above to view its payment status.':
      'የእቁቡን የክፍያ ሁኔታ ለማየት ከላይ እቁብ ይምረጡ።',
  'No active Ekubs to show payment status for.':
      'የክፍያ ሁኔታ የሚታይባቸው ንቁ እቁቦች የሉም።',
  'More to explore': 'ተጨማሪ የሚዳሰሱ',
  'Join': 'ይቀላቀሉ',
  'Membership': 'አባልነት',
  'Per': 'በ',
  'MEMBERSHIP PORTFOLIO': 'የአባልነት ፖርትፎሊዮ',
  'Active': 'ንቁ',
  'Account': 'መለያ',
  'Pay current period': 'የአሁኑን ዙር ክፍያ ይፈጽሙ',
  'Duration': 'ቆይታ',
  'Plan information': 'የእቅድ መረጃ',
  'Choose from gallery': 'ከጋለሪ ይምረጡ',
  'Take a photo': 'ፎቶ አንሳ',
  'Choose an Ekub': 'እቁብ ይምረጡ',
  'Select an Ekub to view': 'ለማየት እቁብ ይምረጡ',
  'Joined': 'ተቀላቅሏል',
  'Full': 'ሙሉ',
  'Half': 'ግማሽ',
  'Quarter': 'አንድ አራተኛ',
  'Share': 'ድርሻ',
  'Half share': 'ግማሽ ድርሻ',
  'Quarter share': 'አንድ አራተኛ ድርሻ',
  'Full contribution': 'ሙሉ መዋጮ',
  'Half contribution': 'ግማሽ መዋጮ',
  'Quarter contribution': 'አንድ አራተኛ መዋጮ',
  'Potential payout': 'ሊገኝ የሚችል ክፍያ',
  'Shares filled': 'የተሟሉ ድርሻዎች',
  'My payment details': 'የክፍያ ዝርዝሮቼ',
  'Choose a period to view its contribution and payment records.':
      'የመዋጮ እና የክፍያ መዝገቦችን ለማየት ዙር ይምረጡ።',
  'Payment period': 'የክፍያ ዙር',
  'Choose a period': 'ዙር ይምረጡ',
  'Period': 'ዙር',
  'Select a period to see its payment details.': 'የክፍያ ዝርዝሩን ለማየት ዙር ይምረጡ።',
  'You joined this Ekub': 'በዚህ እቁብ ውስጥ ተሳትፈሃል',
  'The potential payout is calculated after the 2% service fee. Actual payments must be confirmed by the site.':
      'ሊገኝ የሚችለው ክፍያ የሚሰላው የ2% የአገልግሎት ክፍያ ከተቀነሰ በኋላ ነው። ትክክለኛው ክፍያ በድረ-ገጹ መረጋገጥ አለበት።',
  'Waiting for merchant approval': 'የነጋዴውን ይሁንታ በመጠባበቅ ላይ',
  'Current members': 'አሁን ያሉት አባላት',
  'No members have joined yet.': 'እስካሁን ምንም አባላት አልተቀላቀሉም።',
  'No members yet': 'እስካሁን ምንም አባላት አልተቀላቀሉም።',
  'Your request is waiting for merchant approval. Payments will be available after approval.':
      'ጥያቄዎ የነጋዴውን ይሁንታ በመጠባበቅ ላይ ነው። ከፈቀደ በኋላ ክፍያ ማድረግ ይችላሉ።',
  'Your request is waiting for merchant approval.':
      'ጥያቄዎ የነጋዴውን ይሁንታ በመጠባበቅ ላይ ነው።',
  'You have joined this Ekub.': 'እቁቡን ተቀላቅለዋል።',
  'You’re in!': 'ተቀላቅለዋል!',
  'Done': 'ተጠናቋል',
  'Closed': 'ተዘግቷል',
  'Details': 'ዝርዝሮች',
  'View Details': 'ዝርዝሮችን ይመልከቱ',
  'Your rotation': 'የእርስዎ ተራ',
  'in paid contributions': 'የተከፈለ መዋጮ',
  'Payments': 'ክፍያዎች',
  'Leave': 'ውጣ',
  'Leave this Ekub?': 'ይህንን እቁብ ልተው?',
  'Cancel': 'ሰርዝ',
  'You left the Ekub.': 'እቁቡን ለቀካል፡፡',
  'Loading your Ekubs…': 'እቁቦቻችሁን በመፈለግ ላይ...',
  'Loading your Ekubs...': 'እቁቦቻችሁን በመፈለግ ላይ...',
  'Notifications': 'ማሳወቂያዎች',
  'Your ekub updates': 'የእቁብ ዝመናዎችዎ',
  'Updates are based on your latest account status. Pull down to refresh.':
      'ዝማኔዎች የተመሰረቱት በመለያዎ ወቅታዊ ሁኔታ ላይ ነው። ለማደስ ወደ ታች ይጎትቱ።',
  'New Private Ekub join request': 'አዲስ የግል እቁብ የመቀላቀል ጥያቄ',
  'Requested to join': 'ለመቀላቀል ጥያቄ ቀርቧል',
  'Review it in your merchant dashboard.': 'በነጋዴ ዳሽቦርድዎ ውስጥ ይገምግሙት።',
  'Your ekub requested was approved': 'የጠየቁት እቁብ ጸድቋል',
  'The merchant reviewed your request to join this private ekub.':
      'ነጋዴው ይህንን የግል እቁብ ለመቀላቀል ያቀረቡትን ጥያቄ ገምግሟል።',
  'Merchant account approved': 'የነጋዴ መለያ ጸድቋል',
  'Your merchant account was approved. You can now create private ekubs and manage invite requests.':
      'የነጋዴ መለያዎ ጸድቋል። አሁን የግል እቁቦችን መፍጠር እና የግብዣ ጥያቄዎችን ማስተዳደር ይችላሉ።',
  'Your ekub has started': 'እቁብዎ ተጀምሯል',
  'Identity verification approved': 'የማንነት ማረጋገጫ ጸድቋል',
  'Your identity verification has been approved. You can now join available Ekubs.':
      'የማንነት ማረጋገጫዎ ጸድቋል። አሁን ባሉት እቁቦች ውስጥ መሳተፍ ይችላሉ።',
  'Payment review': 'የክፍያ ግምገማ',
  'Contribution due': 'የሚከፈል መዋጮ',
  'Identity approved': 'ማንነት ተረጋግጧል',
  'Your identity has been verified': 'ማንነትዎ ተረጋግጧል',
  'Profile': 'መገለጫ',
  'Personal': 'የግል መረጃ',
  'First Name': 'የመጀመሪያ ስም',
  'First name': 'የመጀመሪያ ስም',
  'Last name': 'የአያት ስም',
  'Username': 'የተጠቃሚ ስም',
  'Phone number': 'የስልክ ቁጥር',
  'Email address': 'የኢሜይል አድራሻ',
  'Profile Picture': 'የመገለጫ ምስል',
  'Profile picture': 'የመገለጫ ምስል',
  'Take a photo or choose an image': 'ፎቶ አንሳ ወይም ምስል ምረጥ',
  'Update profile picture': 'የመገለጫ ምስልን ያዘምኑ',
  'Choose a profile picture first.': 'መጀመሪያ የመገለጫ ምስል ይምረጡ።',
  'Edit profile': 'መገለጫን ያርትዑ',
  'Update your details and profile photo': 'ዝርዝሮችዎን እና የመገለጫ ፎቶዎን ያዘምኑ',
  'Account & payments': 'መለያ እና ክፍያዎች',
  'Payment methods': 'የክፍያ ዘዴዎች',
  'Manage payout accounts': 'የክፍያ ሂሳቦችን ያስተዳድሩ',
  'Account settings': 'የመለያ ቅንብሮች',
  'Password and account controls': 'የይለፍ ቃል እና የመለያ ቁጥጥሮች',
  'Two-step verification': 'ባለ ሁለት ደረጃ ማረጋገጫ',
  'Protection enabled': 'ጥበቃ ነቅቷል',
  'Email and authenticator enabled. Choose either at sign-in.':
      'ኢሜይል እና የማረጋገጫ መተግበሪያ ነቅተዋል። ወደ ስርዓቱ ሲገቡ ከሁለቱ አንዱን ይምረጡ።',
  'Email one-time code': 'በኢሜይል የሚላክ የአንድ ጊዜ ኮድ',
  'Authenticator app': 'የማረጋገጫ መተግበሪያ',
  'Email verification is enabled. You can choose it at sign in.':
      'የኢሜይል ማረጋገጫ ነቅቷል። ወደ ስርዓቱ ሲገቡ ይህንን መምረጥ ይችላሉ።',
  'Email verification is enabled. You can choose it at sign-in.':
      'የኢሜይል ማረጋገጫ ነቅቷል። ወደ ስርዓቱ ሲገቡ ይህንን መምረጥ ይችላሉ።',
  'Authenticator is enabled. Use it at sign in, or choose email if enabled.':
      'ማረጋገጫ ነቅቷል። ወደ ስርዓቱ ሲገቡ ይጠቀሙበት፤ ወይም አማራጩ ከነቃ ኢሜይልን ይምረጡ።',
  'Authenticator is enabled. Use it at sign-in, or choose email if enabled.':
      'ማረጋገጫ ነቅቷል። ወደ ስርዓቱ ሲገቡ ይጠቀሙበት፤ ወይም አማራጩ ከነቃ ኢሜይልን ይምረጡ።',
  'Authenticator enabled.': 'ማረጋገጫ ነቅቷል',
  'Authenticator enabled': 'ማረጋገጫ ነቅቷል',
  'Turn off two-step verification': 'ባለ ሁለት ደረጃ ማረጋገጫን ያጥፉ',
  'Email codes and authenticator app': 'በኢሜይል የሚላኩ ኮዶች እና የማረጋገጫ መተግበሪያ',
  'App lock': 'መተግበሪያ መቆለፊያ',
  'PIN, pattern, biometric and lock timer':
      'ፒን (PIN)፣ ንድፍ ኮድ፣ ባዮሜትሪክ እና የመቆለፊያ ጊዜ ቆጣሪ',
  'Appearance': 'መልክ',
  'Dark theme · Tap to switch': 'ጨለማ ገጽታ · ለመቀየር ይንኩ',
  'Light theme · Tap to switch': 'ፈካ ያለ ገጽታ · ለመቀየር ይንኩ',
  'Language': 'ቋንቋ',
  'App language': 'የመተግበሪያ ቋንቋ',
  'Amharic': 'አማርኛ',
  'Choose your preferred language': 'የሚመርጡትን ቋንቋ ይምረጡ',
  'Tap to change': 'ለመቀየር ይንኩ',
  'Apply and track your application': 'ያመልክቱ እና ማመልከቻዎን ይከታተሉ',
  'Merchant account': 'የነጋዴ መለያ',
  'Merchant dashboard': 'የነጋዴ ዳሽቦርድ',
  'mekenet dashboard': 'የመቀነት ዳሽቦርድ',
  'Private Ekubs, invited members, and business updates in one place.':
      'የግል እቁቦች፣ የተጋበዙ አባላት እና የንግድ ሥራ መረጃዎች በአንድ ቦታ።',
  'Commission earned': 'የተገኘ ኮሚሽን',
  'Awaiting payout': 'ክፍያ በመጠበቅ ላይ',
  'Your private Ekubs': 'የእርስዎ የግል እቁቦች',
  'Ekubs in your approved business category': 'በእርስዎ የጸደቀ የንግድ ምድብ ውስጥ ያሉ እቁቦች',
  'HOTEL EKUB': 'ሆቴል እቁብ',
  'INVITE CODE': 'የመጋበዣ ኮድ',
  'Member information': 'የአባል መረጃ',
  'Advertisement and location': 'ማስታወቂያ እና ቦታ',
  'Commission ledger': 'የኮሚሽን መዝገብ',
  'Commission is recorded after the admin draws a winner. Payment review and payout control remain with admins.':
      'አሸናፊው በአስተዳዳሪው ከተለየ በኋላ ኮሚሽኑ ይመዘገባል። የክፍያ ግምገማ እና የክፍያ ቁጥጥር በአስተዳዳሪዎች ቁጥጥር ስር ይቆያሉ።',
  'No commissions yet': 'እስካሁን ምንም ኮሚሽኖች የሉም',
  'Products or services': 'ምርቶች ወይም አገልግሎቶች',
  'Website link': 'የድረ-ገጽ አገናኝ',
  'Image': 'ምስል',
  'Save advertisement': 'ማስታወቂያ መዝግብ',
  'Full share': 'ሙሉ ድርሻ',
  '1/3 images max 1 MB each': 'ከ1 እስከ 3 ምስሎች፤ እያንዳንዱ ቢበዛ 1 ሜጋባይት (MB)',
  'Apply with TIN or manage your hosted Ekubs':
      'በTIN ያመልክቱ ወይም የተስተናገዱትን እቁቦች ያስተዳድሩ',
  'Finished Ekubs': 'የተጠናቀቁ እቁቦች',
  'Completed groups and winners': 'የተጠናቀቁ ቡድኖች እና አሸናፊዎች',
  'Full Ekubs': 'ሙሉ እቁቦች',
  'Groups filled to member capacity': 'ቡድኖች በአባላት ሙሉ አቅም ተሞልተዋል',
  'About & support': 'ስለ እኛ እና ድጋፍ',
  'About': 'ስለ',
  'How Mekenet Ekub works': 'መቀነት እቁብ እንዴት እንደሚሰራ',
  'Privacy policy': 'የግላዊነት ፖሊሲ',
  'Your information and choices': 'መረጃዎ እና ምርጫዎችዎ',
  'Terms of service': 'የአገልግሎት ውሎች',
  'Platform rules and fees': 'የመድረክ ደንቦች እና ክፍያዎች',
  'Contact support': 'የድጋፍ አገልግሎትን ያግኙ',
  'Call support': 'ለድጋፍ አገልግሎትን ይደውሉ',
  'Get help with your account': 'በመለያዎ ላይ እርዳታ ያግኙ',
  'Rate the app': 'መተግበሪያውን ደረጃ ይስጡ',
  'Write a review on Google Play': 'በGoogle Play ላይ ግምገማ ይጻፉ',
  'Sign out': 'ውጣ',
  'Identity verified': 'ማንነት ተረጋግጧል',
  'Identity unverified': 'ማንነት አልተረጋገጠም',
  'Your identity has been approved.': 'ማንነትዎ ጸድቋል።',
  'Verify your identity to unlock full features.':
      'ሁሉንም ባህሪያት ለመጠቀም ማንነትዎን ያረጋግጡ።',
  'View': 'ይመልከቱ',
  'Student': 'ተማሪ',
  'Teachers': 'መምህራን',
  'Teacher': 'መምህር',
  'Worker': 'ሠራተኛ',
  'Drivers': 'አሽከርካሪዎች',
  'Student Ekub': 'የተማሪዎች እቁብ',
  'Teacher Ekub': 'የመምህራን እቁብ',
  'Government Employees Ekub': 'የመንግስት ሰራተኞች እቁብ',
  'Government Employees': 'የመንግስት ሰራተኞች',
  'Merkato Merchants': 'የመርካቶ ነጋዴዎች',
  'Hotel': 'ሆቴል',
  'Category': 'ምድብ',
  'All': 'ሁሉም',
  'Daily': 'የቀን',
  'Weekly': 'ሳምንታዊ',
  'Monthly': 'ወርሃዊ',
  'Frequency': 'ድግግሞሽ',
  'Payment Frequency': 'የክፍያ ጊዜያት',
  'Base Amount': 'መሠረታዊ መጠን',
  'Contribution per period': 'በእያንዳንዱ ዙር የሚጣለው',
  'Contribution Amount': 'በእያንዳንዱ ዙር የሚጣለው',
  'Number of Periods': 'የሚጣልበት ጊዜ',
  'Duration / Periods': 'የሚጣልበት ጊዜ',
  'Potential Net Payout': 'ሊገኝ የሚችል ክፍያ',
  'After 2% service fee': 'ከ2% የአገልግሎት ክፍያ በኋላ',
  'Search Ekubs': 'እቁቦችን ይፈልጉ',
  'Ekub name': 'የእቁብ ስም',
  'Note': 'ማስታወሻ',
  'Start a new Ekub': 'አዲስ እቁብ ጀምር',
  'Start a new': 'አዲስ እቁብ ጀምር',
  'Your applications': 'ማመልከቻዎችዎ',
  'Send application': 'ማመልከቻ ይላኩ',
  'No applications submitted yet. Your requests will appear here.':
      'እስካሁን ምንም ማመልከቻዎች አልቀረቡም። ጥያቄዎችዎ እዚህ ይታያሉ።',
  'Enter a name': 'ስም ያስገቡ',
  'Enter an amount': 'መጠን ያስገቡ',
  'Enter 2 to 500 periods': 'ከ2 እስከ 500 የሚሆኑ ጊዜያትን ያስገቡ',
  'Optional': 'አማራጭ',
  'Not submitted': 'አልቀረበም',
  'Protect this app': 'ይህንን መተግበሪያ ይጠብቁ',
  'Ask for your PIN, pattern, or biometric when you return.':
      'ሲመለሱ የፒን (PIN) ቁጥርዎን፣ የንድፍ ኮድዎን ወይም ባዮሜትሪክ መረጃዎን ያስገቡ።',
  'Unlock method': 'የመክፈቻ ዘዴ',
  'Lock after leaving the app': 'መተግበሪያውን ከለቀቁ በኋላ ይቆልፉ',
  'Create a 4-8 digit PIN': 'ከ4 እስከ 8 አሃዞች ያሉት ፒን ይፍጠሩ',
  'Confirm PIN': 'ፒን ያረጋግጡ',
  'Save app lock': 'የመተግበሪያ መቆለፊያን ያስቀምጡ',
  'Immediately': 'ወዲያውኑ',
  '1 minute': '1 ደቂቃ',
  '5 minutes': '5 ደቂቃዎች',
  '10 minutes': '10 ደቂቃዎች',
  '1 hour': '1 ሰዓት',
  'Never': 'በጭራሽ',
  'PIN': 'ፒን',
  'Pattern': 'ንድፍ ኮድ',
  'Fingerprint / biometric': 'የጣት አሻራ / ባዮሜትሪክ',
  'Members': 'አባላት',
  'Periods': 'ዙር',
  'ETB': 'ብር',
  'Admin Dashboard': 'የአስተዳዳሪ ዳሽቦርድ',
  'Admin': 'አስተዳዳሪ',
  'Add Partner': 'አጋር ያክሉ',
  'Tools': 'መሳሪያዎች',
  'Filled': 'የሞላ',
  'View Detail': 'ዝርዝሩን ይመልከቱ',
  'Detail': 'ዝርዝር',
  'Approved': 'ተረጋግጧል',
  'Item': 'ዕቃ',
  'Item’s Ekubs': 'የዕቃዎች ዕቁቦች',
  'Ekub Applications': 'የእቁብ ማመልከቻ',
  'Send your plan to an administrator for review.': 'ዕቅድዎን ለግምገማ ለአስተዳዳሪ ይላኩ።',
  'Contribution': 'መዋጮ',
  'shares available': 'ድርሻ ይገኛል',
  'share available': 'ድርሻ ይገኛል',
  'Your personal information is locked after identity verification. You can still update your profile picture and Email.':
      'ማንነትዎ ከተረጋገጠ በኋላ የግል መረጃዎ ይቆለፋል። ሆኖም፣ የመገለጫ ፎቶዎን እና የኢሜይል አድራሻዎን ማዘመን ይችላሉ።',
  'Save the bank or wallet accounts used for receiving payouts.':
      'ክፍያዎችን ለመቀበል የሚያገለግሎትን የባንክ ወይም የዲጂታል ቦርሳ አካውንቶን ይመዝግቡ።',
  'Add payout account': 'ክፍያ የሚቀበሉበትን አካውንት ያክሉ',
  'Your account information is kept private.': 'የመለያ መረጃዎ በግል ይጠበቃል።',
  'Bank or wallet': 'ባንክ ወይም የዲጂታል ቦርሳ',
  'Account number': 'የአካውንት ቁጥር',
  'Account holder name': 'የአካውንት ባለቤት ስም',
  'Account holder name:': 'የአካውንት ባለቤት ስም፡',
  'Confirm payment': 'ክፍያውን ያረጋግጡ',
  'Choose method': 'ዘዴ ይምረጡ',
  'Pay & confirm': 'ክፍያ ይፈጽሙና ያረጋግጡ',
  'Amount to pay': 'የሚከፈል መጠን',
  'Tap how you’ll pay': 'የክፍያ ዘዴዎን ይምረጡ',
  'Transfer': 'አስተላልፍ',
  'ETB transfer': 'የብር ማስተላለፍ',
  'Not configured': 'አልተዋቀረም',
  'Confirm you paid': 'ክፍያ መፈጸምዎን ያረጋግጡ',
  'Transaction ID / reference': 'የግብይት መለያ / ማጣቀሻ',
  'Checking…': 'በማረጋገጥ ላይ…',
  'ID is available': 'መለያ ቁጥሩ አዲስ ነው',
  'Check transaction ID': 'የግብይት መለያ ቁጥሩን ያረጋግጡ',
  'Attach a receipt image': 'የደረሰኝ ምስል ያያይዙ',
  'I confirm I transferred this amount to the account shown. The payment stays pending until an administrator verifies the transaction ID and receipt.':
      'ይህንን ገንዘብ በተጠቀሰው አካውንት ላይ ያስተላለፍኩ መሆኔን አረጋግጣለሁ። አስተዳዳሪው የግብይት መለያ ቁጥሩን እና ደረሰኙን እስኪያረጋግጥ ድረስ ክፍያው በመጠባበቅ ላይ ይቆያል።',
  'Confirm my payment': 'ክፍያዬን አረጋግጥ',
  'Save account': 'አካውነቱን መዝግብ',
  'Change password': 'የይለፍ ቃል ይቀይሩ',
  'Current password': 'የአሁኑ ሚስጥራዊ ማለፊያ ቁልፍ',
  'Enter your current password': 'የአሁኑን የይለፍ ቃልዎን ያስገቡ',
  'New password': 'አዲስ የይለፍ ቃል',
  'Confirm new password': 'አዲስ የይለፍ ቃል ያረጋግጡ',
  'Update password': 'የይለፍ ቃል ያዘምኑ',
  'Delete account': 'መለያ ሰርዝ',
  'Delete my account': 'አካውንቴን ሰርዝ',
  "You cannot delete your account while part of a running Ekub. This action cannot be undone.":
      "በሂደት ላይ ያለ 'እቁብ' ውስጥ እያሉ መለያዎን መሰረዝ አይችሉም። ይህን ድርጊት መቀልበስ አይቻልም።",
  'Confirm with your password': 'በይለፍ ቃልዎ ያረጋግጡ',
  'Reason': 'ምክንያት',
  'I no longer need the service': 'አሁን አገልግሎቱ አያስፈልገኝም።',
  'I have privacy concerns': 'ስለ ግላዊነት ስጋቶች አሉኝ።',
  'I created a second account': 'ሁለተኛ አካውንት ፈጠርኩ።',
  'I am not satisfied with the service': 'በአገልግሎቱ አልረካሁም።',
  'I had a problem with a payment': 'ክፍያ ላይ ችግር አጋጥሞኝ ነበር።',
  'Other': 'ሌላ',
  'Tell us more': 'ተጨማሪ ይንገሩን',
  'Pending requests': 'በመጠባበቅ ላይ ያሉ ጥያቄዎች',
  'Advertisement Title': 'የማስታወቂያ ርዕስ',
  'Location on this Ekub': 'እቁቡ ያለበት ቦታ',
  'About Mekenet Ekub': 'ስለ መቀነት እቁብ',
  'Saving together. Growing together.': 'አብሮ መቆጠብ። አብሮ ማደግ።',
  'How it works': 'እንዴት እንደሚሰራ',
  'Review each group’s category, schedule, contribution, duration and capacity. KYC approval is required before joining.':
      'የእያንዳንዱን ቡድን ምድብ፣ የጊዜ ሰሌዳ፣ አስተዋጽኦ፣ ቆይታ እና አቅም ይገምግሙ። ከመቀላቀልዎ በፊት የKYC (ደንበኛን የማወቅ ሂደት) ማረጋገጫ ያስፈልጋል።',
  "Review each group's category, schedule, contribution, duration and capacity. KYC approval is required before joining.":
      'የእያንዳንዱን ቡድን ምድብ፣ የጊዜ ሰሌዳ፣ አስተዋጽኦ፣ ቆይታ እና አቅም ይገምግሙ። ከመቀላቀልዎ በፊት የKYC (ደንበኛን የማወቅ ሂደት) ማረጋገጫ ያስፈልጋል።',
  'Payout fee': 'የክፍያ ክፍያ',
  'The stated service fee is 2% of the collected pool. The winner receives 98%, subject to the group rules.':
      'የተገለጸው የአገልግሎት ክፍያ ከተሰበሰበው ጠቅላላ ገንዘብ 2% ነው። አሸናፊው 98% ያገኛል፤ ይህ ደግሞ በቡድኑ ደንቦች መሰረት ይሆናል።',
  'Information collected': 'የተሰበሰበ መረጃ',
  'How it is used': 'እንዴት ጥቅም ላይ ይውላል',
  'Who can see it': 'ማን ሊያየው ይችላል',
  'Retention and deletion': 'ማቆየት እና መሰረዝ',
  'Your account details, identity documents, payment records and saved payout accounts.':
      'የመለያዎ ዝርዝሮች፣ የማንነት ሰነዶች፣ የክፍያ መዝገቦች እና ያስቀመጧቸው የክፍያ መቀበያ መለያዎች።',
  'To verify identity, manage Ekub groups, confirm contributions, send reminders and security codes, pay winners and prevent abuse.':
      'ማንነትን ለማረጋገጥ፣ የዕቁብ ቡድኖችን ለማስተዳደር፣ መዋጮዎችን ለማረጋገጥ፣ አስታዋሾችን እና የደህንነት ኮዶችን ለመላክ፣ አሸናፊዎችን ለመክፈል እንዲሁም አላግባብ መጠቀምን ለመከላከል ነው።',
  "Authorised administrators and partners with matching permissions can review identity and payment information. Members cannot see other members' documents or bank details.":
      'ፈቃድ ያላቸው አስተዳዳሪዎች እና ተመጣጣኝ መብቶች ያላቸው አጋሮች፣ የማንነት እና የክፍያ መረጃን መመልከት ይችላሉ። አባላት የሌሎች አባላትን ሰነዶች ወይም የባንክ ዝርዝር መረጃዎች ማየት አይችሉም።',
  'Authorised administrators and partners with matching permissions can review identity and payment information. Members cannot see other members’ documents or bank details.':
      'ፈቃድ ያላቸው አስተዳዳሪዎች እና ተመጣጣኝ መብቶች ያላቸው አጋሮች፣ የማንነት እና የክፍያ መረጃን መመልከት ይችላሉ። አባላት የሌሎች አባላትን ሰነዶች ወይም የባንክ ዝርዝር መረጃዎች ማየት አይችሉም።',
  "Authorized administrators and partners with matching permissions can review identity and payment information. Members cannot see other members' documents or bank details.":
      'ፈቃድ ያላቸው አስተዳዳሪዎች እና ተመጣጣኝ መብቶች ያላቸው አጋሮች፣ የማንነት እና የክፍያ መረጃን መመልከት ይችላሉ። አባላት የሌሎች አባላትን ሰነዶች ወይም የባንክ ዝርዝር መረጃዎች ማየት አይችሉም።',
  'Authorized administrators and partners with matching permissions can review identity and payment information. Members cannot see other members’ documents or bank details.':
      'ፈቃድ ያላቸው አስተዳዳሪዎች እና ተመጣጣኝ መብቶች ያላቸው አጋሮች፣ የማንነት እና የክፍያ መረጃን መመልከት ይችላሉ። አባላት የሌሎች አባላትን ሰነዶች ወይም የባንክ ዝርዝር መረጃዎች ማየት አይችሉም።',
  'You may request account deletion when you are not part of a running Ekub. Some accounting records may be retained as described in the site policy.':
      'በአሁኑ ወቅት በሂደት ላይ ያለ “እቁብ” ውስጥ በማይሳተፉበት ጊዜ፣ መለያዎን እንዲሰረዝ መጠየቅ ይችላሉ። በድረ-ገጹ ፖሊሲ ላይ እንደተገለጸው፣ አንዳንድ የሂሳብ መዝገቦች ሊያዙ (ሊቀመጡ) ይችላሉ።',
  'Verification': 'ማረጋገጫ',
  'Account safety': 'የመለያ ደህንነት',
  'Follow Mekenet Ekub': 'መቀነት እቁብ ተከተል',
  'Member capacity reached': 'የአባላት አቅም ተሞልቷል',
  'No finished Ekubs yet.': 'እስካሁን የተጠናቀቁ እቁቦች የሉም።',
  'Secure': 'አስተማማኝ',
  'Protected accounts': 'የተጠበቁ መለያዎች',
  'Digital Ekub Platform': 'ዲጂታል እቁብ መድረክ',
  'My profile': 'የእኔ መገለጫ',
  'Apply Ekub': 'ለእቁብ ይመዝገቡ',
  'My status': 'ሁኔታዬ',
  'KYC verification': 'የKYC ማረጋገጫ',
  'My joined ekub': 'የእኔ እቁብ',
  'Transparent': 'ግልጽ',
  'Track your ekub': 'የእቁብዎን ሁኔታ ይከታተሉ',
  'Registered members': 'የተመዘገቡ አባላት',
  'Start your ekub journey': 'የእቁብ ጉዞዎን ይጀምሩ',
  'Explore Ekubs': 'እቁቦችን ያስሱ',
  'Digital': 'ዲጂታል',
  'Created Ekubs': 'የተፈጠሩ እቁቦች',
  'Ekub made Simple': 'እቁብ ያቀላል',
  'A clear digital process from registration to participation and payout.':
      'ከምዝገባ እስከ ተሳትፎ እና ክፍያ ድረስ ግልጽ የሆነ ዲጂታል ሂደት።',
  'Verify': 'አረጋግጡ',
  'Complete KYC verification before joining active Ekubs.':
      'በንቁ እቁቦች ውስጥ ከመሳተፍዎ በፊት የKYC ማረጋገጫ ሂደቱን ያጠናቅቁ።',
  'Choose': 'ይምረጡ',
  'Explore available Ekubs and select the one that matches your needs.':
      'ያሉትን እቁቦች ያስሱ እና ከፍላጎትዎ ጋር የሚስማማውን ይምረጡ።',
  'Participate': 'ተሳትፎ ያድርጉ',
  'Make your scheduled contributions and follow your Ekub status digitally.':
      'የተመደቡትን ክፍያዎች ይፈጽሙ፤ እንዲሁም የእቁብ ሁኔታዎን በዲጂታል መንገድ ይከታተሉ።',
  'Community Feedback': 'የማህበረሰብ አስተያየት',
  'What people say about Mekenet Ekub': 'ሰዎች ስለ መቀነት እቁብ ምን ይላሉ',
  'Reviews shared through the website footer are visible here to everyone.':
      'በድረ-ገጹ ግርጌ በኩል የተጋሩ ግምገማዎች እዚህ ለሁሉም ሰው ይታያሉ።',
  'IMPORTANT RULE': 'አስፈላጊ ደንብ',
  'A 2% service fee is deducted from the amount received by an Ekub winner. The remaining 98% is the net payout.':
      'ከእቁብ አሸናፊ ከሚያገኘው ገንዘብ ላይ የ2% የአገልግሎት ክፍያ ይቀነሳል። ቀሪው 98% ደግሞ የተጣራ ክፍያ ይሆናል።',
  'START TODAY': 'ዛሬውኑ ይጀምሩ',
  'Ready to join your digital Ekub community?':
      'ለዲጂታል እቁብ ማህበረሰብዎ ለመቀላቀል ዝግጁ ነዎት?',
  'Create your account and begin your journey with Mekenet Ekub.':
      'መለያዎን ይፍጠሩ እና ጉዞዎን ከመቀነት እቁብ ጋር ይጀምሩ።',
  'A modern digital platform for transparent and organized Ekub management.':
      'ለግልጽ እና የተደራጀ የእቁብ አስተዳደር የሚያገለግል ዘመናዊ ዲጂታል መድረክ።',
  'OUR STORY': 'ታሪካችን',
  'THE IDEA': 'ሀሳቡ',
  'A familiar tradition, with helpful digital tools':
      'አጋዥ ዲጂታል መሣሪያዎች የታከሉበት የታወቀ ወግ',
  'Clear group details': 'የቡድን ዝርዝሮችን ያጽዱ',
  'Organized participation': 'የተደራጀ ተሳትፎ',
  'Account protection': 'የመለያ ጥበቃ',
  'HOW IT WORKS': 'እንዴት እንደሚሰራ',
  'Understand the steps before you join': 'ከመቀላቀልዎ በፊት ደረጃዎቹን ይረዱ',
  'Explore': 'ያስሱ',
  'Review and verify': 'ይገምግሙ እና ያረጋግጡ',
  'SERVICE FEE': 'የአገልግሎት ክፍያ',
  'Service fee on payout': 'ክፍያ ሲፈጸም የሚከፈል የአገልግሎት ክፍያ',
  'Review the displayed payout estimate and terms before joining.':
      'ከመቀላቀልዎ በፊት፣ የሚታየውን የክፍያ ግምት እና ውሎች ይገምግሙ።',
  'Join our community online': 'በመስመር ላይ ማህበረሰባችንን ይቀላቀሉ',
  'READY TO TAKE A LOOK?': 'ለመመልከት ዝግጁ ነዎት?',
  'Find an Ekub that fits your plan.': 'ከዕቅድዎ ጋር የሚስማማ እቁብ ያግኙ።',
  "WE'RE HERE TO HELP": 'እዚህ የመጣነው ለመርዳት ነው',
  "Let's talk.": 'እንወያይ።',
  'CALL US': 'ይደውሉልን',
  'Speak with our team': 'ከቡድናችን ጋር ይነጋገሩ',
  'Call now': 'አሁን ይደውሉ',
  'Working hours': 'የሥራ ሰዓት',
  'Monday – Saturday': 'ሰኞ - ቅዳሜ',
  'Sunday: Closed': 'እሑድ፡ ዝግ',
  'Please note the listed hours before calling.':
      'እባክዎ ከመደወልዎ በፊት የተዘረዘሩትን ሰዓቶች ልብ ይበሉ።',
  'Email us': 'ኢሜይል ይላኩልን',
  'What can we help with?': 'በምን ልንረዳዎት እንችላለን?',
  'Keep your account safe': 'መለያዎን ደህንነቱ የተጠበቀ ያድርጉ',
  'FOLLOW US': 'ይከተሉን',
  'Stay connected with Mekenet Ekub': 'ከመቀነት እቁብ ጋር እንደተገናኙ ይቆዩ',
  'Looking for an Ekub?': 'እቁብ ይፈልጋሉ?',
  'Lookin for an Ekub?': 'እቁብ ይፈልጋሉ?',
  'You can browse available groups and review their details directly on the website.':
      'በድረ-ገጹ ላይ ያሉትን ቡድኖች ማሰስ እና ዝርዝር መረጃዎቻቸውን በቀጥታ መመልከት ይችላሉ።',
  'View available Ekubs': 'ያሉትን እቁቦች ይመልከቱ',
  'Mekenet Ekub brings the familiar tradition of እቁብ into a more organized digital experience—helping members explore groups, understand the rules, and follow their participation in one place.':
      'መቀነት እቁብ፣ የታወቀውን የእቁብ ባህል ወደ ይበልጥ የተደራጀ ዲጂታል ተሞክሮ ያመጣል፤ ይህም አባላት ቡድኖችን እንዲያስሱ፣ ደንቦቹን እንዲረዱ እና ተሳትፏቸውን በአንድ ቦታ እንዲከታተሉ ያግዛል።',
  'Mekenet Ekub brings the familiar tradition of እቁብ into an organized digital experience, helping members explore groups and follow their participation.':
      'መቀነት እቁብ፣ በደንብ የሚታወቀውን የእቁብ ባህል ወደ ተደራጀ ዲጂታል ተሞክሮ በመቀየር፣ አባላት የተለያዩ ቡድኖችን እንዲያስሱ እና ተሳትፏቸውን እንዲከታተሉ ያስችላቸዋል።',
  'Ekub is built around people contributing regularly and taking turns receiving a pooled amount. Mekenet Ekub is designed to make the group information and participation process easier to follow.':
      'እቁብ ሰዎች በመደበኛነት ገንዘብ በማዋጣት እና በተራቸው የተሰበሰበውን ገንዘብ በመቀበል ላይ የተመሰረተ ነው። መቀነት እቁብ ስለ ቡድኑ መረጃን ለመከታተል እና በሂደቱ ውስጥ ለመሳተፍ የሚያስችለውን አሰራር ይበልጥ ቀላል ለማድረግ ተዘጋጅቷል።',
  'Review each Ekub’s category, contribution frequency, base amount, duration, and member capacity before deciding whether to join.':
      'በአንድ እቁብ ውስጥ ለመሳተፍ ከመወሰንዎ በፊት፣ የእቁቡን ምድብ፣ የመዋጮ ድግግሞሽ፣ መነሻ መጠን፣ ቆይታ እና የአባላት አቅም ይገምግሙ።',
  'Use your account to keep track of the Ekubs you join and view relevant group and payment information.':
      'የተቀላቀሏቸውን እቁቦች ለመከታተል እና ከቡድኑ እና ከክፍያ ጋር የተያያዙ መረጃዎችን ለማየት መለያዎን ይጠቀሙ።',
  'Account access uses your password, with optional email OTP or an authenticator app for an additional layer of protection.':
      'ወደ መለያዎ ለመግባት የይለፍ ቃልዎን ይጠቀማሉ። ለተጨማሪ ደህንነት በኢሜይል የሚላክ OTP ወይም የማረጋገጫ መተግበሪያ በአማራጭነት መጠቀም ይችላሉ።',
  'Every group can have its own schedule and capacity. Check the details shown on the Ekub page and make sure the contribution plan fits your needs.':
      'እያንዳንዱ ቡድን የራሱ የሆነ የጊዜ ሰሌዳ እና የአቅም ገደብ ሊኖረው ይችላል። በእቁብ ገጽ ላይ ያሉትን ዝርዝሮች ይመልከቱ፣ እንዲሁም የመዋጮ ዕቅዱ ከፍላጎትዎ ጋር መስማማቱን ያረጋግጡ።',
  'Browse available Ekubs and compare their categories, schedules, and contribution amounts.':
      'ያሉትን እቁቦች ይመልከቱ፤ ምድቦቻቸውን፣ የጊዜ ሰሌዳዎቻቸውን እና የመዋጮ መጠኖቻቸውን ያወዳድሩ።',
  'Read the group details and complete any required account or identity verification steps.':
      'የቡድኑን ዝርዝሮች ያንብቡ እና የሚያስፈልጉትን የመለያ ወይም የማንነት ማረጋገጫ ደረጃዎች ያጠናቅቁ።',
  'Choose an eligible share option where offered, then follow the group’s payment schedule and updates.':
      'አማራጭ ሲቀርብ ብቁ የሆነውን የድርሻ አማራጭ ይምረጡ፤ ከዚያም የቡድኑን የክፍያ መርሃ ግብር እና ዝመናዎች ይከታተሉ።',
  'The platform’s stated fee is 2% of the collected pool. The winner receives the remaining 98%, subject to the group’s applicable rules.':
      'በመድረኩ ላይ የተገለጸው ክፍያ ከተሰበሰበው ጠቅላላ ገንዘብ 2% ነው። አሸናፊው በቡድኑ ተፈጻሚ ደንቦች መሰረት ቀሪውን 98% ያገኛል።',
  'Follow our official pages for news and updates.':
      'ለዜናዎች እና ወቅታዊ መረጃዎች ኦፊሴላዊ ገጾቻችንን ይከተሉ።',
  'Explore the available groups and read their details at your own pace.':
      'ያሉትን ቡድኖች ያስሱ እና ዝርዝሮቻቸውን በፈለጉት ፍጥነት ያንብቡ።',
  'Have a question about an Ekub, your account, or how the platform works? Reach out using the contact details below.':
      'ስለ እቁብ፣ ስለ መለያዎ ወይም መድረኩ እንዴት እንደሚሰራ ጥያቄ አለዎት? ከታች ባሉት የእውቂያ ዝርዝሮች ያግኙን።',
  'For questions or assistance, call the Mekenet Ekub contact number.':
      'ለጥያቄዎች ወይም እርዳታ፣ የመቀነት እቁብ የእውቂያ ስልክ ቁጥር ላይ ይደውሉ።',
  'Questions about finding or joining an Ekub, account access, verification, payment schedules, or understanding platform fees.':
      'እቁብን ስለማግኘት ወይም ስለመቀላቀል፣ ወደ መለያ ስለመግባት፣ ማረጋገጫ፣ የክፍያ መርሃ ግብር ወይም የመድረኩን ክፍያዎች ስለመረዳት ጥያቄዎች።',
  'Never share your password or authenticator code with anyone claiming to provide support.':
      'ድጋፍ እሰጣለሁ ብሎ ለሚቀርብ ማንኛውም ሰው የይለፍ ቃልዎን ወይም የማረጋገጫ ኮድዎን በፍጹም አያጋሩ።',
  'When a member wins a period, a 2% service fee is deducted from the approved gross pool. The winner receives 98%.':
      'አንድ አባል በአንድ ዙር ሲያሸንፍ፣ ከተፈቀደው ጠቅላላ ገንዘብ 2% የአገልግሎት ክፍያ ይቀነሳል። አሸናፊው 98% ይቀበላል።',
  'Payments submitted after the applicable due date may receive a late-payment penalty according to the Ekub configuration.':
      'ከተወሰነው የመክፈያ ቀን በኋላ የቀረቡ ክፍያዎች፣ በእቁቡ ውቅር መሰረት የዘገየ ክፍያ ቅጣት ሊያስከትሉ ይችላሉ።',
  'KYC approval is required before joining active Ekubs.':
      'ንቁ እቁቦችን ከመቀላቀልዎ በፊት የKYC ማረጋገጫ ማግኘት ያስፈልጋል።',
  'Terms & Agreement': 'ውሎች እና ስምምነት',
  '2% Service Fee': '2% የአገልግሎት ክፍያ',
  'Late Payment': 'ዘግይቶ የሚደረግ ክፍያ',
  'A 2% fee is deducted from the approved gross pool when a member wins a period. The winner receives 98%.':
      'አንድ አባል በተወሰነ ጊዜ ውስጥ ሲያሸንፍ፣ ከተፈቀደው ጠቅላላ የገንዘብ መጠን ላይ 2% ክፍያ ይቀነሳል። አሸናፊውም 98%-ውን ይቀበላል።',
  'Late payments may receive a penalty according to the Ekub configuration.':
      'በእቁብ አወቃቀሩ መሰረት፣ ክፍያዎችን በወቅቱ አለመፈጸም ቅጣት ሊያስከትል ይችላል።',
  'KYC approval is required before joining active Ekubs. Check the contribution schedule before joining.':
      'በንቁ እቁቦች ውስጥ ከመሳተፍዎ በፊት የKYC (የደንበኛ መለያ) ማረጋገጫ ያስፈልጋል። ከመቀላቀልዎ በፊት የአዋዋጣ መርሃ ግብሩን ይመልከቱ።',
  'How Mekenet Ekub collects, uses and protects your information.':
      'መቀነት እቁብ መረጃዎን እንዴት እንደሚሰበስብ፣ እንደሚጠቀምበት እና እንደሚጠብቀው።',
  'Information we collect': 'የምንሰበስበው መረጃ',
  'How we use it': 'እንዴት እንደምንጠቀምበት',
  'Retention and account deletion': 'መረጃን ማቆየት እና መለያን መሰረዝ',
  'Suspended accounts': 'የታገዱ መለያዎች',
  'Your choices': 'የእርስዎ ምርጫዎች',
  'Your name, username, phone number and email; KYC details (date of birth, gender, ID or passport number and images, personal photo and video agreement); payment records including transaction numbers and receipt screenshots; and the bank accounts you save to receive payouts.':
      'ስምዎ፣ የተጠቃሚ ስምዎ፣ ስልክ ቁጥርዎ እና ኢሜይልዎ፤ የKYC መረጃዎች (የትውልድ ቀን፣ ጾታ፣ የመታወቂያ ወይም የፓስፖርት ቁጥር እና ምስሎች፣ የግል ፎቶ እና የቪዲዮ ስምምነት)፤ የግብይት ቁጥሮችን እና የደረሰኝ ምስሎችን የሚያካትቱ የክፍያ መዝገቦች፤ እንዲሁም ክፍያ ለመቀበል ያስቀመጧቸው የባንክ መለያዎች።',
  'To verify your identity, run Ekub groups, confirm contributions, send payment reminders and security codes, pay out winners, and prevent fraud or abuse of the platform.':
      'ማንነትዎን ለማረጋገጥ፣ የእቁብ ቡድኖችን ለማስተዳደር፣ መዋጮዎችን ለማረጋገጥ፣ የክፍያ ማስታወሻዎችን እና የደህንነት ኮዶችን ለመላክ፣ አሸናፊዎችን ለመክፈል እና ማጭበርበርን ወይም መድረኩን አላግባብ መጠቀምን ለመከላከል ነው።',
  'Only authorised Mekenet Ekub administrators and partners with the matching permission can review KYC and payment information. We do not sell your personal information. Other members cannot see your documents or bank details.':
      'ተገቢው ፈቃድ ያላቸው የመቀነት እቁብ አስተዳዳሪዎች እና አጋሮች ብቻ የKYC እና የክፍያ መረጃን ማየት ይችላሉ። የግል መረጃዎን አንሸጥም። ሌሎች አባላት ሰነዶችዎን ወይም የባንክ ዝርዝሮችዎን ማየት አይችሉም።',
  'You can delete your account from Settings at any time when you are not in a running Ekub. Deleting removes your profile, KYC documents and saved payment methods. Past contribution and payout records may be kept in anonymised form for accounting and audit purposes, and we keep the reason you give for leaving.':
      'በሂደት ላይ ባለ እቁብ ውስጥ በማይሳተፉበት ጊዜ ከቅንብሮች መለያዎን መሰረዝ ይችላሉ። መለያዎን ሲሰርዙ መገለጫዎ፣ የKYC ሰነዶችዎ እና ያስቀመጧቸው የክፍያ ዘዴዎች ይወገዳሉ። የቀድሞ የመዋጮ እና የክፍያ መዝገቦች ለሂሳብ እና ለኦዲት ዓላማ ማንነት በማይገልጽ መልኩ ሊቀመጡ ይችላሉ፤ ለመልቀቅ የሰጡትን ምክንያትም እንጠብቃለን።',
  'Support will never ask for your password or authenticator code.':
      'የድጋፍ አገልግሎቱ የይለፍ ቃልዎን ወይም የማረጋገጫ ኮድዎን በጭራሽ አይጠይቅዎትም።',
  'Find our official channels and community updates.':
      'የእኛን ኦፊሻላዊ ቻናሎች እና የማህበረሰብ ዝመናዎችን ያግኙ።',
  'Monday to Saturday, 12:00 AM - 11:00 PM.':
      'ከሰኞ እስከ ቅዳሜ፣ ከጠዋቱ 12:00 እስከ ምሽቱ 11:00።',
  'Sunday closed.': 'እሑድ ዝግ ነው።',
};

final List<String> _amharicTranslationKeys = _amharicTranslations.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

String mekenetTranslate(String source) {
  if (mekenetLanguageCode != 'AM') return source;
  if (source.trim().toLowerCase() == 'your') return 'የእርስዎ';
  final adImages = RegExp(
    r'^(\d+)\s*/\s*3\s+images\s*[·•]\s*max 1 MB each$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (adImages != null) {
    return '${adImages.group(1)} / 3 ምስሎች · እያንዳንዱ ቢበዛ 1 ሜጋባይት (MB)';
  }
  final leaveEkub = RegExp(
    r'^You will leave\s+(.+?)\.?$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (leaveEkub != null) {
    return '${leaveEkub.group(1)!.trim()} ትወጣለህ?';
  }
  final readyPeriods = RegExp(
    r'^(\d+)\s+periods?\s+(?:is|are) ready for payment$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (readyPeriods != null) {
    final count = int.tryParse(readyPeriods.group(1)!) ?? 0;
    return count == 1
        ? 'ዙር $count ለክፍያ ዝግጁ ነው'
        : 'ዙር $count ለክፍያ ዝግጁ ናቸው';
  }
  final payPeriod = RegExp(
    r'^Pay period\s+(\d+)\s*[·•]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (payPeriod != null) {
    final amount = payPeriod
        .group(2)!
        .replaceAll(RegExp(r'\s*ETB\b', caseSensitive: false), ' ብር');
    return 'ዙር ${payPeriod.group(1)} ክፈል · $amount';
  }
  final paymentTransfer = RegExp(
    r'^Transfer\s+(.+?)\s+to this account\. Admin will verify the receipt\.?$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (paymentTransfer != null) {
    final amount = paymentTransfer
        .group(1)!
        .replaceAll(RegExp(r'\s*ETB\b', caseSensitive: false), ' ብር');
    return 'ወደዚህ አካውንት $amount ያስተላልፉ። አስተዳዳሪው ደረሰኙን ያረጋግጣል።';
  }
  final shareDetails = RegExp(
    r'^Your share:\s*(FULL|HALF|QUARTER)\s*[·•]\s*contribution per period:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (shareDetails != null) {
    final share = switch (shareDetails.group(1)!.toUpperCase()) {
      'FULL' => 'ሙሉ',
      'HALF' => 'ግማሽ',
      _ => 'ሩብ (1/4)',
    };
    final amount = shareDetails
        .group(2)!
        .replaceAll(RegExp(r'\s*ETB\b', caseSensitive: false), ' ብር');
    return 'የእርስዎ ድርሻ፡ $share፤ በእያንዳንዱ ዙር የሚደረግ መዋጮ፡ $amount';
  }
  final sharePrompt = RegExp(
    r'^Choose your share for\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (sharePrompt != null) {
    return 'ለ${sharePrompt.group(1)!.trim()} ድርሻዎን ይምረጡ';
  }
  final joinedShare = RegExp(
    r'^You joined\s+(.+)\s+with a\s+(FULL|HALF|QUARTER)\s+share\.?$',
    caseSensitive: false,
  ).firstMatch(source.trim());
  if (joinedShare != null) {
    final share = switch (joinedShare.group(2)!.toUpperCase()) {
      'FULL' => 'ሙሉ',
      'HALF' => 'ግማሽ',
      _ => 'አንድ አራተኛ',
    };
    return 'በ$share ድርሻ ${joinedShare.group(1)!.trim()} ተቀላቅለሃል';
  }
  var translated = source;
  translated = translated.replaceAllMapped(
    RegExp(r'(\d+)\s+ekubs?\s+in your rotation', caseSensitive: false),
    (match) => 'በእርስዎ የእቁብ ዙር ውስጥ ያሉ ${match.group(1)} እቁቦች',
  );
  for (final english in _amharicTranslationKeys) {
    if (english == 'Per') continue;
    translated = translated.replaceAll(
      RegExp(
        RegExp.escape(english).replaceAll(' ', r'\s+'),
        caseSensitive: false,
      ),
      _amharicTranslations[english]!,
    );
  }
  translated = translated.replaceAll(
    RegExp(r'\bPer\b', caseSensitive: false),
    'በ',
  );
  translated = translated.replaceFirst(RegExp(r'Welcome,\s*'), 'እነኳን ደህና መጡ፣ ');
  translated = translated.replaceAllMapped(
    RegExp(r'(\d[\d,.]*)\s*ETB\b'),
    (match) => '${match.group(1)} ብር',
  );
  return translated;
}

class LocalizedText extends StatelessWidget {
  const LocalizedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  @Deprecated('Use textScaler instead.')
  final double? textScaleFactor;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  Widget build(BuildContext context) => material.Text(
    mekenetTranslate(data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaleFactor: textScaleFactor,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null
        ? null
        : mekenetTranslate(semanticsLabel!),
    semanticsIdentifier: semanticsIdentifier,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
