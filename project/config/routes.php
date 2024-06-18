<?php

Router::addRoute(['GET', 'POST'], '/stress', 'App\Controller\ControllerOverhead@stress');
Router::addRoute(['GET', 'POST'], '/data', 'App\Controller\ControllerOverhead@data');
