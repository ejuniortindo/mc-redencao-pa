<?php
$_ENV['APP_MODE'] = 'development';
$__process_assets = false;

return [

	'app.siteName' => 'Mapa cultural de Redenção-PA',
	'app.siteDescription' => "O Mapa Cultural do municipio de Redenção Pará é uma plataforma colaborativa que reúne informações sobre agentes, espaços, eventos, projetos culturais e oportunidades",

	

	'app.lcode' => 'pt_BR',
    
	#'homeHeader.banner' => 'https://mapacultural.pa.gov.br/assets/mapacultural.pa.gov.br/img/banner-paulo-gustavo.img.yzs9c2.png',
    #'homeHeader.bannerLink' => 'https://mapacultural.pa.gov.br/files/agent/7/caderno-de-orientacoes-pcac-27-09-2023.pdf',
    #'homeHeader.downloadableLink' => true,

	#'homeHeader.secondBanner' => 'https://mapacultural.pa.gov.br/assets/mapacultural.pa.gov.br/img/banner-paulo-gustavo.img.yzs9c2.png',
    #'homeHeader.secondBannerLink' => 'https://mapacultural.pa.gov.br/files/agent/7/caderno-de-orientacoes-pcac-27-09-2023.pdf',
    #'homeHeader.secondDownloadableLink' => true,

    'app.verifiedSealsIds' => '1',
    'cep.token' => '',
    
    'slim.debug' => true,

    'app.mode' => $_ENV['APP_MODE'],

    // deixe true somente se estiver trabalhando nos mapeamentos das entidades
    'doctrine.isDev' => false, 

    //'themes.active' => 'SpCultura',TemplateV1
	'themes.active' => 'PMR',

    /* ASSET MANAGER */
    'themes.assetManager' => new \MapasCulturais\AssetManagers\FileSystem([
        'publishPath' => BASE_PATH . 'assets/',

        'mergeScripts' => $__process_assets,
        'mergeStyles' => $__process_assets,

        'process.js' => !$__process_assets ?
                'cp {IN} {OUT}':
                'terser {IN} --source-map --output {OUT} ',

        'process.css' => !$__process_assets ?
                'cp {IN} {OUT}':
                'uglifycss {IN} > {OUT}',

        'publishFolderCommand' => 'cp -R {IN} {PUBLISH_PATH}{FILENAME}'
    ]),
];