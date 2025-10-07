<?php 
use \MapasCulturais\i;

return [
    /* Primeira linha do logo configurável */
    'logo.title' => env('LOGO_TITLE','Mapa'),

    /* Segunda linha do logo configurável */
    'logo.subtitle' => env('LOGO_SUBTITLE','Cultural'),

    /* Cores da logo */
    'logo.colors' => [
        "var(--mc-primary-300)",
        "var(--mc-primary-500)",
        "var(--mc-secondary-300)",
        "var(--mc-secondary-500)",
    ],

    /* 
    Define o nome do asset da imagem da logo do site - Substituirá a logo padrão

    ex: `img/meu-mapa-logo.jpg` (pasta assets/img/meu-mapa-logo.jpg do tema) 
    */
    'logo.image' => env('LOGO_IMAGE', 'https://redencao.pa.gov.br/img/logos/logo-marron.png'),

    /* Esconde o título e subtitulo */
    'logo.hideLabel' => env('LOGO_HIDELABEL', true),
];
