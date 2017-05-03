<?php

/*
 * Provisioning module for PaaS.
 */

use OneCS\App;

require __DIR__.'/../../../vendor/autoload.php';


function opennebulapaas_MetaData() {
    return App::getInstance()->run('paas:metadata');
}


/**
 * Configuration.
 */
function opennebulapaas_ConfigOptions() {
    return App::getInstance()->run('paas:defineConfiguration');
}


/**
 * Create account.
 */
function opennebulapaas_CreateAccount( array $params ) {
    return App::getInstance()->run('paas:createAccount', [
        $params['serviceid'],
        $params['configoption1'], // tariff_name
        $params['configoption2'], // limit_cpu_amount
        $params['configoption3'], // limit_cpu_percentage
        $params['configoption4'], // limit_ram
        $params['configoption5'], // limit_hdd
        $params['configoption6'], // template_name_pattern
        $params['configoption7'], // groups_additional_pattern
        $params['configoption8'], // on_virtual_network
        $params['configoption9'], // storage_label_pattern
        $params['configoption10'], // custom_field_name_operating_system
        $params['configoption11'], // custom_field_name_storage_type
        $params['customfields'], // array of custom fields
    ] );
}


/**
 * Suspend account.
 */
function opennebulapaas_SuspendAccount( array $params ) {
    return App::getInstance()->run('paas:suspendAccount', [
        $params['serviceid'],
    ]);
}


/**
 * Unsuspend account.
 */
function opennebulapaas_UnsuspendAccount( array $params ) {
    return App::getInstance()->run('paas:unsuspendAccount', [
        $params['serviceid'],
    ]);
}


/**
 * Terminate account.
 */
function opennebulapaas_TerminateAccount( array $params ) {
    return App::getInstance()->run('paas:terminateAccount', [
        $params['serviceid'],
    ]);
}


/**
 * Change password.
 */
function opennebulapaas_ChangePasswordON( array $params ) {
    return App::getInstance()->run('paas:changePassword', [
        $params['serviceid'],
    ]);
}


/**
 * Sign in to OpenNebula panel.
 */
function opennebulapaas_LoginLink( array $params ) {
    return App::getInstance()->run('paas:auth', [
        $params['username'],
        $params['password'],
    ]);
}


function opennebulapaas_AdminCustomButtonArray() {
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
