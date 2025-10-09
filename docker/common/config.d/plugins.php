<?php

return [
    'plugins' => [
        'MultipleLocalAuth' => [ 'namespace' => 'MultipleLocalAuth' ],
        'SamplePlugin' => ['namespace' => 'SamplePlugin'],
        'SpamDetector',
    	'AdminLoginAsUser',
    	'Accessibility',
    
    	'MapasBlame' => [
            'namespace' => 'MapasBlame',
            'config' => [
                'request.logData.PATCH' => function ($data) {
                    return $data;
                },
            ]
        ],
    
    	"MetadataKeyword" => [
            "namespace" => "MetadataKeyword",
            "config" => [
                'location' => ['En_Municipio', 'En_Nome_Logradouro', 'En_Bairro']
            ]
        ],
    	
    ]
];