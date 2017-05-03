<?php

/*
 * Provisioning module for IaaS.
 */

use OneCS\App;

require __DIR__.'/../../../vendor/autoload.php';


function opennebulaiaas_MetaData() {
    return App::getInstance()->run('iaas:metadata');
}


/**
 * Configuration.
 */
function opennebulaiaas_ConfigOptions() {
    return App::getInstance()->run('iaas:defineConfiguration');
}


/**
 * Create account.
 */
function opennebulaiaas_CreateAccount( array $params ) {
    return App::getInstance()->run('iaas:createAccount', [
        $params['serviceid'],
        $params['configoption1'], // tariff_name
        $params['configoption2'], // limit_vm
        $params['configoption3'], // limit_cpu
        $params['configoption4'], // limit_ram
        $params['configoption5'], // limit_hdd
    ] );
}


/**
 * Suspend account.
 */
function opennebulaiaas_SuspendAccount( array $params ) {
    return App::getInstance()->run('iaas:suspendAccount', [
        $params['serviceid'],
    ]);
}


/**
 * Unsuspend account.
 */
function opennebulaiaas_UnsuspendAccount( array $params ) {
    return App::getInstance()->run('iaas:unsuspendAccount', [
        $params['serviceid'],
    ]);
}


/**
 * Terminate account.
 */
function opennebulaiaas_TerminateAccount( array $params ) {
    return App::getInstance()->run('iaas:terminateAccount', [
        $params['serviceid'],
    ]);
}


/**
 * Change password.
 */
function opennebulaiaas_ChangePasswordON( array $params ) {
    return App::getInstance()->run('iaas:changePassword', [
        $params['serviceid'],
    ]);
}


/**
 * Sign in to OpenNebula panel.
 */
function opennebulaiaas_LoginLink( array $params ) {
    return App::getInstance()->run('iaas:auth', [
        $params['username'],
        $params['password'],
    ]);
}


function opennebulaiaas_AdminCustomButtonArray() {
    return [
        'Change password to OpenNebula panel' => 'ChangePasswordON',
    ];
}


// /**
//  * Update limits.
//  */
// function opennebulapaas_ChangePackage( array $params ) {
//     // TODO later...
// }
