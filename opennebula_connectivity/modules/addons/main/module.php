<?php

// Addon file for WHMCS 6.3

use OneCS\App;

require __DIR__.'/../../../vendor/autoload.php';


/**
 * Configuration.
 */
function opennebula_connectivity_config() {
    return App::getInstance()->run('setup:defineConfiguration');
}


/**
 * Activate the module.
 */
function opennebula_connectivity_activate() {
    return App::getInstance()->run('setup:activate');
}


/**
 * Deactivate the module.
 */
function opennebula_connectivity_deactivate() {
    return App::getInstance()->run('setup:deactivate');
}


/**
 * Front-controller for Admin Area.
 *
 * @param array $vars configuration values
 */
function opennebula_connectivity_output( array $vars ) {
    echo App::getInstance()->run('admin:output', [
        $_POST['submit_type'],
        $_POST['tags'],
        $_POST['ip'],
        $_POST['amount'],
    ]);
}
