<?php
$routes = $config['routes'];

$list = [
    #'lpg/teste' => 5,    
    
];

foreach($list as $route => $id) {
    $routes['shortcuts'][$route] = ['opportunity', 'single', [$id]];
}

$routes['shortcuts']['entidades-resumo'] = ['pasettings', 'querys'];
$routes['shortcuts']['entidades-resumov2'] = ['pasettings', 'querysv2'];
return ['routes' => $routes];