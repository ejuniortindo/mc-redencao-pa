<?php 
use MapasCulturais\i;

return [
    'app.siteName' => 'Mapa Cultural de Redenção (PA)',
    'app.siteDescription' => "O Mapa Cultural de Redenção (PA) é uma plataforma colaborativa que reúne informações sobre agentes, espaços, eventos, projetos culturais e oportunidades",
    
    // Define o tema ativo no site principal. Deve ser informado o namespace do tema e neste deve existir uma classe Theme.
    'themes.active' => 'PMR',
	'app.lcode' => 'pt_BR',

    // Ids dos selos verificadores. Para utilizar múltiplos selos informe os ids separados por vírgula.
    'app.verifiedSealsIds' => '1', 

	'app.geoDivisionsHierarchy' => [
        'pais'              => ['name' => i::__('País'),            'showLayer' => true],
        'estado'            => ['name' => i::__('Estado'),          'showLayer' => true],
        'mesorregiao'       => ['name' => i::__('Mesorregião'),     'showLayer' => true],
        //'RI'  => ['name' => i::__('Região de integração'),'showLayer' => true],
        'microrregiao'      => ['name' => i::__('Microrregião'),    'showLayer' => true],
        'municipio'         => ['name' => i::__('Município'),       'showLayer' => true],
    ],

    'app.geoDivisionsFilters' => [16],
    
    //'app.geoDivisionsShowAgentRI' => true,

];