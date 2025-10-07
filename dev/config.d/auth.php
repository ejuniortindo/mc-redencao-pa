<?php

return [
    //'auth.provider' => 'Fake',
     'auth.provider' => '\MultipleLocalAuth\Provider',
     'auth.config' => [
         'salt' => env('AUTH_SALT', null),
         'timeout' => '24 hours',
         //url de suporte por chat para ser enviado nos emails
         'urlSupportChat' => 'https://redencao.pa.gov.br',
            
            //url de suporte por email para ser enviado nos emails
         'urlSupportEmail' => 'https://redencao.pa.gov.br',
            
            //url do site de suporte para ser enviado nos emails
         'urlSupportSite' => 'https://redencao.pa.gov.br',
     
    	 //url dos termos de uso para utilizar a plataforma
         'urlTermsOfUse' => 'https://www.google.com',
     
         //Habilita registro e login através do CPF
            //'enableLoginByCPF' => true,
            
            //apelido do metadata que será salvo o campo CPF
            //'metadataFieldCPF' => 'documento',
    //     'strategies' => [
    //         'Facebook' => [
    //             'app_id' => env('AUTH_FACEBOOK_APP_ID', null),
    //             'app_secret' => env('AUTH_FACEBOOK_APP_SECRET', null),
    //             'scope' => env('AUTH_FACEBOOK_SCOPE', 'email'),
    //         ],
    //         'LinkedIn' => [
    //             'api_key' => env('AUTH_LINKEDIN_API_KEY', null),
    //             'secret_key' => env('AUTH_LINKEDIN_SECRET_KEY', null),
    //             'redirect_uri' => '/autenticacao/linkedin/oauth2callback',
    //             'scope' => env('AUTH_LINKEDIN_SCOPE', 'r_emailaddress')
    //         ],
    //         'Google' => [
    //             'client_id' => env('AUTH_GOOGLE_CLIENT_ID', null),
    //             'client_secret' => env('AUTH_GOOGLE_CLIENT_SECRET', null),
    //             'redirect_uri' => '/autenticacao/google/oauth2callback',
    //             'scope' => env('AUTH_GOOGLE_SCOPE', 'email'),
    //         ],
    //         'Twitter' => [
    //             'app_id' => env('AUTH_TWITTER_APP_ID', null),
    //             'app_secret' => env('AUTH_TWITTER_APP_SECRET', null),
    //         ],
    //     ]
     ]
];