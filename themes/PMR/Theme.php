<?php

namespace PMR;
use MapasCulturais\Themes\BaseV2;
use MapasCulturais\App;

/**
 * @method void import(string $components) Importa lista de componentes Vue. * 
 */
class Theme extends BaseV2\Theme
{

    static function getThemeFolder()
    {
        return __DIR__;
    }

    function _init()
    {
        parent::_init();

        $app = App::i();
    
    	$app->hook('GET(site.webmanifest)', function() use ($app) {
            /** @var \MapasCulturais\Controller $this */
            $this->json([
                'icons' => [
                    [ 'src' => $app->view->asset('img/favicon.192.png', false), 'type' => 'image/png', 'sizes' => '192x192' ],
                    [ 'src' => $app->view->asset('img/favicon.512.png', false), 'type' => 'image/png', 'sizes' => '512x512' ],
                ],
            ]);
        });
    
    	$app->hook('template(<<*>>.<<*>>.main-footer-logo):before', function () use($app) {
            /** @var \MapasCulturais\Themes\BaseV2\Theme $this */

            $this->part('pmr-footer-support');
        });

        
    }

    
}
