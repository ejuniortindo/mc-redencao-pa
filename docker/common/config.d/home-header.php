<?php 
use \MapasCulturais\i;

return [
    /* 
    Define o nome do asset da imagem do background e banner no header da home - Substituirá o background padrão
    ex: `img/meu-home-header-background.jpg` (pasta assets/img/meu-home-header-background.jpg do tema)
    */
    #'homeHeader.background' => 'img/home/home-header/home-header.jpg',

    /* Primeiro banner */
    'homeHeader.banner' => 'img/home/home-banners/banner-aldir-blanc.png',
//    'homeHeader.bannerLink' => 'https://redencao.pa.gov.br/',
//    'homeHeader.downloadableLink' => false,  /* Define se link é para download ou para abrir em uma nova aba */
	
	/* Segundo banner */
    'homeHeader.secondBanner' => 'img/home/home-banners/banner-forum-de-cultura.png',
//    'homeHeader.secondBannerLink' => 'https://redencao.pa.gov.br/',
//    'homeHeader.secondDownloadableLink' => false,

    /* Terceiro banner */
    'homeHeader.thirdBanner' => 'img/home/home-banners/banner-ouvidoria-da-cultura.png',
    'homeHeader.thirdBannerLink' => 'https://falabr.cgu.gov.br/v2/?modoOuvidoria=1&ouvidoriaInterna=false',
    'homeHeader.thirdDownloadableLink' => false,
];
