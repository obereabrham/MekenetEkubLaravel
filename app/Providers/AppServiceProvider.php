<?php
namespace App\Providers;
use App\View\TwigEngine;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\View;
use Illuminate\Support\ServiceProvider;
use Twig\Environment;
use Twig\Loader\FilesystemLoader;
use Twig\TwigFilter;
use Twig\TwigFunction;
use Twig\TwigTest;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton('twig', function () {
            $twig = new Environment(new FilesystemLoader(resource_path('views')), ['autoescape'=>'html','cache'=>false]);
            $twig->addFunction(new TwigFunction('url_for', function (string $endpoint, array $params = [], array $named = []): string { return route_url($endpoint, array_replace($params,$named)); }, ['is_variadic'=>true]));
            $twig->addFunction(new TwigFunction('format_amount', fn ($amount) => number_format((float)$amount,2,'.',',')));
            $twig->addFunction(new TwigFunction('get_flashed_messages', function (bool $with_categories = false): array {
                $items=session()->pull('_flashes',[]);
                return $with_categories ? array_map(fn($m)=>[$m['type']??'message',$m['message']??''],$items) : array_column($items,'message');
            }));
            $twig->addFunction(new TwigFunction('csrf_field', fn()=>'<input type="hidden" name="_token" value="'.e(csrf_token()).'">',['is_safe'=>['html']]));
            $twig->addFunction(new TwigFunction('csrf_token', fn()=>csrf_token()));
            $twig->addFunction(new TwigFunction('pay_bal', fn($payment)=>app(\App\Support\EkubService::class)->payBalance((array)$payment)));
            $twig->addFunction(new TwigFunction('period_bal', fn($ekub,$period)=>app(\App\Support\EkubService::class)->currentPeriodBalance((array)$ekub,(int)$period)));
            $twig->addFilter(new TwigFilter('tojson',fn($v)=>json_encode($v,JSON_HEX_TAG|JSON_HEX_APOS|JSON_HEX_AMP|JSON_HEX_QUOT|JSON_UNESCAPED_UNICODE),['is_safe'=>['html']]));
            $twig->addFilter(new TwigFilter('float',fn($v)=>(float)$v));
            $twig->addFilter(new TwigFilter('int',fn($v)=>(int)$v));
            $twig->addFilter(new TwigFilter('list',fn($v)=>is_array($v)?array_values($v):(is_iterable($v)?iterator_to_array($v):[])));
            $twig->addFilter(new TwigFilter('select',fn($v)=>array_values(array_filter((array)$v))));
            $twig->addFilter(new TwigFilter('unique',fn($v)=>array_values(array_unique((array)$v,SORT_REGULAR))));
            $twig->addFilter(new TwigFilter('sort',function($v){$v=(array)$v;sort($v);return $v;}));
            $twig->addFilter(new TwigFilter('map',fn($v,$attribute=null)=>array_map(fn($item)=>data_get($item,$attribute),(array)$v)));
            $twig->addFilter(new TwigFilter('groupby',function($v,$attribute){$groups=[];foreach((array)$v as $item)$groups[(string)data_get($item,$attribute,'')][]=$item;ksort($groups);return $groups;}));
            $twig->addFilter(new TwigFilter('selectattr',fn($v,$attribute,$test=null,$expected=null)=>array_values(array_filter((array)$v,fn($item)=>$this->attributeMatches(data_get($item,$attribute),$test,$expected)))));
            $twig->addFilter(new TwigFilter('rejectattr',fn($v,$attribute,$test=null,$expected=null)=>array_values(array_filter((array)$v,fn($item)=>!$this->attributeMatches(data_get($item,$attribute),$test,$expected)))));
            $twig->addFilter(new TwigFilter('sum',fn($v,$attribute=null)=>array_sum(array_map(fn($item)=>(float)($attribute?data_get($item,$attribute,0):$item),(array)$v))));
            $twig->addFilter(new TwigFilter('max',fn($v)=>max((array)$v)));
            $twig->addFilter(new TwigFilter('min',fn($v)=>min((array)$v)));
            $twig->addFilter(new TwigFilter('format',fn($format,...$args)=>sprintf((string)$format,...$args)));
            $twig->addFilter(new TwigFilter('get',fn($v,$key,$default=null)=>is_array($v)?($v[$key]??$default):data_get($v,$key,$default)));
            $twig->addFilter(new TwigFilter('split',fn($v,$delimiter=',')=>explode((string)$delimiter,(string)$v)));
            $twig->addFilter(new TwigFilter('replace',fn($v,$search,$replacement='')=>str_replace($search,$replacement,(string)$v)));
            $twig->addTest(new TwigTest('equalto',fn($v,$expected)=>$v==$expected));
            $twig->addTest(new TwigTest('ne',fn($v,$expected)=>$v!=$expected));
            $twig->addGlobal('session',$this->app['session.store']);
            return $twig;
        });
    }
    public function boot(): void
    {
        $resolver=$this->app['view.engine.resolver'];
        $resolver->register('twig',fn()=>new TwigEngine($this->app->make('twig')));
        $this->app['view']->addExtension('twig','twig');
        View::composer('*',function($view){
            $me=app(\App\Http\Controllers\WebsiteController::class)->currentUser();
            $stats=['members'=>0,'ekubs'=>0,'payouts'=>0,'profit'=>0,'collected'=>0];$ads=[];$permissions=[];$pending=0;
            try{
                $stats=['members'=>DB::table('users')->where('role','member')->where('status','active')->count(),'ekubs'=>DB::table('ekubs')->count(),'payouts'=>(float)DB::table('payouts')->sum('net_amount'),'profit'=>(float)DB::table('payouts')->sum('service_fee'),'collected'=>(float)DB::table('payments')->where('status','approved')->sum('approved_amount')];
                $ads=DB::table('ads')->orderBy('slot')->pluck('image')->all();
                if($me&&$me['role']==='admin')$pending=DB::table('ekub_applications')->where('status','pending')->count();
                if($me&&$me['role']==='partner')$permissions=array_values(array_filter(explode(',',DB::table('partners')->where('user_id',$me['id'])->value('permissions')??'')));
            }catch(\Throwable){}
            $view->with(['me'=>$me,'user'=>$me,'full_name'=>$me?trim($me['first_name'].' '.$me['last_name']):'',
                'stats'=>$stats,'registered_members'=>$stats['members'],'created_ekubs'=>$stats['ekubs'],'total_payouts'=>$stats['payouts'],
                'kyc_status'=>$me['kyc_status']??null,'partner_permissions'=>$permissions,'pending_applications'=>$pending,'site_ads'=>$ads,
                'categories'=>config('ekub.categories'),'frequencies'=>config('ekub.frequencies'),'methods'=>config('ekub.methods')]);
        });
    }
    private function attributeMatches(mixed $actual,mixed $test,mixed $expected): bool
    {
        return match($test){'equalto','equal'=>$actual==$expected,'ne','notequalto'=>$actual!=$expected,default=>(bool)$actual};
    }
}
