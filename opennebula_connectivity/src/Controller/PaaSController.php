<?php
namespace OneCS\Controller;

use OneCS\Controller\ProvisioningController;
use Exception;

class PaaSController extends ProvisioningController {


    const COSTOM_FIELD_VALUE_OS_DEFAULT = 'Linux';
    const CUSTOM_FIELD_VALUE_STORAGE_DEFAULT = 'SATA';
    const PATTERN_VAR_OPERATING_SYSTEM = '{operating_system}';
    const PATTERN_VAR_STORAGE_TYPE = '{storage_type}';


    /**
     * {@inheritDoc}
     *
     * @see \OneCS\Controller\ProvisioningController::getUsernameTemplate()
     */
    protected function getUsernameTemplate() {
        return 'user_paas_%s';
    }



    /**
     * Metadata of the PaaS provisioning module.
     */
    public function metadataAction() {
        return [
            'DisplayName' => 'OpenNebula PaaS',
            'RequiresServer' => true,
        ];
    }


    /**
     * Define configuration for PaaS product.
     */
    public function defineConfigurationAction() {
        return [
            'tariff_name' => [ // configoption1
                'FriendlyName' => 'Tariff name',
                'Type' => 'text',
                'Size' => 16,
                'Description' => '<br>Allowed characters: lowercase letters, underscore, digits.'
            ],
            'limit_cpu_amount' => [ // configoption2
                'FriendlyName' => 'CPU limit (amount)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 1,
            ],
            'limit_cpu_percentage' => [ // configoption3
                'FriendlyName' => 'CPU limit (percentage)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 100,
            ],
            'limit_ram' => [ // configoption4
                'FriendlyName' => 'RAM limit (MB)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 1024,
            ],
            'limit_hdd' => [ // configoption5
                'FriendlyName' => 'HDD limit for additional disks (GB)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 0.,
            ],

            'template_name_pattern' => [ // configoption6
                'FriendlyName' => 'Pattern of template name',
                'Type' => 'text',
                'Size' => 32,
                'Default' => 'template_'.self::PATTERN_VAR_OPERATING_SYSTEM.'_'.self::PATTERN_VAR_STORAGE_TYPE.'_cloud_foo',
                'Description' =>
                        '<br>Available variables in the pattern:<br><i>'.self::PATTERN_VAR_OPERATING_SYSTEM.'</i>, <i>'.self::PATTERN_VAR_STORAGE_TYPE.'</i>.'
                        .'<br>Example:<br><i>template_'.self::PATTERN_VAR_OPERATING_SYSTEM.'_'.self::PATTERN_VAR_STORAGE_TYPE.'_cloud_foo</i>.'
                        .'<br>Allowed characters: lowercase letters, underscore, digits.'
            ],

            'groups_additional_pattern' => [ // configoption7
                    'FriendlyName' => 'Additional groups to add user to',
                    'Type' => 'text',
                    'Size' => 32,
                    'Default' => 'paas_free_'.self::PATTERN_VAR_STORAGE_TYPE.'_'.self::PATTERN_VAR_OPERATING_SYSTEM.',paas_'.self::PATTERN_VAR_STORAGE_TYPE.'_windows',
                    'Description' =>
                            '<br>Comma-separated list of additional groups to add user to.'
                            .'<br>Available variables in names of groups:<br><i>'.self::PATTERN_VAR_OPERATING_SYSTEM.'</i>, <i>'.self::PATTERN_VAR_STORAGE_TYPE.'</i>.'
                            .'<br>Example:<br><i>paas_free_'.self::PATTERN_VAR_STORAGE_TYPE.'_'.self::PATTERN_VAR_OPERATING_SYSTEM.',paas_'.self::PATTERN_VAR_STORAGE_TYPE.'_windows</i>.'
                            .'<br>Allowed characters: lowercase letters, underscore, digits.'
            ],

            'on_virtual_network' => [ // configoption8
                'FriendlyName' => 'Name of the OpenNebula Virtual Network',
                'Type' => 'text',
                'Size' => 32,
            ],

            'storage_label_pattern' => [ // configoption9
                'FriendlyName' => 'Pattern of storage label',
                'Type' => 'text',
                'Size' => 32,
                'Default' => 's_'.self::PATTERN_VAR_STORAGE_TYPE,
                'Description' =>
                        '<br>Available variables in the pattern:<br><i>'.self::PATTERN_VAR_OPERATING_SYSTEM.'</i>, <i>'.self::PATTERN_VAR_STORAGE_TYPE.'</i>.'
                        .'<br>Example:<br><i>s_'.self::PATTERN_VAR_OPERATING_SYSTEM.'_'.self::PATTERN_VAR_STORAGE_TYPE.'</i>.'
                        .'<br>Allowed characters: lowercase letters, underscore, digits.'
            ],

            // Custom fields

            'custom_field_name_operating_system' => [ // configoption10
                'FriendlyName' => 'Custom field for OS',
                'Type' => 'text',
                'Size' => 32,
                'Default' => 'on_os',
                'Description' =>
                        '<br>Name of client area custom field to specify operating system.'
                        .'<br>It should be a dropdown list. All values are case insensitive.'
                        .'<br>If there is no such custom field or value is empty then default value will be "<i>'.self::COSTOM_FIELD_VALUE_OS_DEFAULT.'</i>".'
            ],
            'custom_field_name_storage_type' => [ // configoption11
                'FriendlyName' => 'Custom field for type of a storage',
                'Type' => 'text',
                'Size' => 32,
                'Default' => 'on_storage',
                'Description' =>
                        '<br>Name of client area custom field to specify storage type.'
                        .'<br>It should be a dropdown list. All values are case insensitive.'
                        .'<br>If there is no such custom field or value is empty then default value will be "<i>'.self::CUSTOM_FIELD_VALUE_STORAGE_DEFAULT.'</i>".'
            ],
        ];
    }


    /**
     * Create PaaS account.
     */
    public function createAccountAction(
            $service_id,
            $tariff_name,
            $limit_cpu_amount,
            $limit_cpu_percentage,
            $limit_ram,
            $limit_hdd,
            $template_name_pattern,
            $groups_additional_pattern,
            $on_virtual_network,
            $storage_label_pattern,
            $custom_field_name_operating_system,
            $custom_field_name_storage_type,
            array $custom_fields
    ) {
        try {

            // generate username
            $username = $this->getUsernameByServiceID( $service_id );

            // generate password
            $password = $this->generatePassword();

            // get OpenNebula client

            $on = $this->get('one:client');
            $on_helper = $this->get('one:client:helper');

            // allocate new user
            $user_id = $on->userAllocate( $username, $password, '' );

            // get values of selected operating system and type of a storage

            $operating_system = strtolower( (string)@$custom_fields[ $custom_field_name_operating_system ] );
            $storage_type = strtolower( (string)@$custom_fields[ $custom_field_name_storage_type ] );

            if( !$operating_system ) {
                $operating_system = self::COSTOM_FIELD_VALUE_OS_DEFAULT;
            }

            if( !$storage_type ) {
                $storage_type = self::CUSTOM_FIELD_VALUE_STORAGE_DEFAULT;
            }

            // choose appropriate template

            $template_name = str_replace( [
                self::PATTERN_VAR_OPERATING_SYSTEM,
                self::PATTERN_VAR_STORAGE_TYPE,
            ], [
                $operating_system,
                $storage_type,
            ], $template_name_pattern );

            // set groups for the user

            $group_pool_info = $on_helper->getAllGroups();

            $group_id_paas = $group_pool_info['paas']['id'];
            $group_id_users = $group_pool_info['users']['id'];

            $groups_additional = array_filter( array_map( function ( $group_pattern ) use ( $operating_system, $storage_type ) {
                return str_replace( [
                    self::PATTERN_VAR_OPERATING_SYSTEM,
                    self::PATTERN_VAR_STORAGE_TYPE,
                ], [
                    $operating_system,
                    $storage_type,
                ], trim( $group_pattern ) );
            }, explode( ',', $groups_additional_pattern ) ) );

            $groups_additional[] = $tariff_name;

            $groups_additional_ids = array_map( function ( $group ) use ( $group_pool_info, $on ) {

                $group_id = @$group_pool_info[ $group ]['id'];

                if( !$group_id ) {
                    $group_id = $on->groupAllocate( $group );
                }

                return $group_id;

            }, $groups_additional );

            $group_id_tariff = $group_pool_info[ $tariff_name ]['id'];

            $on->userChgrp( $user_id, $group_id_paas );
            $on->userAddgroup( $user_id, $group_id_users );

            foreach( $groups_additional_ids as $group_additional_id ) {
                $on->userAddgroup( $user_id, $group_additional_id );
            }

            // set limits for the user

            $limit_vm = 1;
            $limit_cpu_amount = intval( $limit_cpu_amount );
            $limit_cpu_percentage = (float)intval( $limit_cpu_percentage ) / 100.;
            $limit_ram = intval( $limit_ram );

            $limit_hdd = intval( (float)$limit_hdd * 1024 ); // GB -> MB

            $on->userQuota( $user_id, preg_replace( '/\s+/u', '', "
                <VM_QUOTA>
                    <VM>
                        <CPU><![CDATA[$limit_cpu_percentage]]></CPU>
                        <MEMORY><![CDATA[$limit_ram]]></MEMORY>
                        <SYSTEM_DISK_SIZE><![CDATA[$limit_hdd]]></SYSTEM_DISK_SIZE>
                        <VMS><![CDATA[$limit_vm]]></VMS>
                    </VM>
                </VM_QUOTA>
            " ) );

            // define tag of a storage for the VM

            $stotage_label = str_replace( [
                self::PATTERN_VAR_OPERATING_SYSTEM,
                self::PATTERN_VAR_STORAGE_TYPE,
            ], [
                $operating_system,
                $storage_type,
            ], trim( $storage_label_pattern ) );

            // find best storage for the VM

            $datastores_all = $on_helper->getAllDatastores();

            $datastores_matching = array_filter($datastores_all, function (array $datastore) use ($stotage_label) {
                return false !== strpos((string) @$datastore['TEMPLATE']['LABELS'], $stotage_label);
            });

            $datastore_best = array_pop($datastores_matching);
            foreach ($datastores_matching as $datastore) {
                if ((int) $datastore['FREE_MB'] > (int) $datastore_best['FREE_MB']) {
                    $datastore_best = $datastore;
                }
            }

            $datastore_name = isset($datastore_best['NAME']) ? $datastore_best['NAME'] : null;

            // get template contents

            $vm_templates = $on_helper->getAllTemplates();
            $template_info = $vm_templates[ $template_name ];

            $template_xml_all = $on->templateInfo( (int)$template_info['ID'] );

            $matches = [];
            preg_match( '/.*(?<VM_TEMPLATE_XML><TEMPLATE>.+<\/TEMPLATE>).*/u', $template_xml_all, $matches );
            $template_xml = $matches['VM_TEMPLATE_XML'];

            // set name for the template

            $vm_name = 'vm_paas_'.$service_id;
            $this->setVMTemplateAttribute( 'NAME', $vm_name, $template_xml );

            // set CPU and RAM limits in the template

            $this->setVMTemplateAttribute( 'CPU', $limit_cpu_percentage, $template_xml );
            $this->setVMTemplateAttribute( 'VCPU', $limit_cpu_amount, $template_xml );
            $this->setVMTemplateAttribute( 'MEMORY', $limit_ram, $template_xml );

            // set Virtual Network and IP for the template

            $this->setVMTemplateAttribute( 'NIC', "
                <NETWORK>$on_virtual_network</NETWORK>
            ", $template_xml );

            // set Datastore requirement

            if (null !== $datastore_name) {
                $this->setVMTemplateAttribute('SCHED_DS_REQUIREMENTS', sprintf('"NAME=%s"', $datastore_name), $template_xml);
            }

//             echo '<pre>';
//             var_export( htmlentities( $template_xml ) );
//             echo '</pre>';
//             die();

            // create vm from the template

            $vm_id = (int)$on->vmAllocate( $template_xml, false );

            // chown and chmod the vm

            $on->vmChown( $vm_id, $user_id, $group_id_tariff );
            $on->vmChmod(
                $vm_id,
                1, 1, 1,
                0, 0, 0,
                0, 0, 0
            );

            // set all permissions

            // TODO Set all permissions for PaaS

            // save username and password of the instance of product

            $this
                ->get('whmcs')
                ->updateClientProduct([
                    'serviceid' => $service_id,
                    'serviceusername' => $username,
                    'servicepassword' => $password,
                ]);

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to create account due to unexpected error: '.$ex->getMessage();
        }
    }


    private function setVMTemplateAttribute( $attribute, $value, &$template_xml ) {

        $value = is_numeric( $value )
            ? '<![CDATA['.$value.']]>'
            : (string)$value;

        $attribute_quoted = preg_quote( $attribute, '/' );

        if( preg_match( "/<$attribute_quoted>/u", $template_xml ) ) {

            $template_xml = preg_replace(
                "/<$attribute_quoted>.*<\/$attribute_quoted>/u",
                "<$attribute_quoted>$value</$attribute_quoted>",
                $template_xml
            );

        } else {

            $template_xml = str_replace(
                '</TEMPLATE>',
                "<$attribute_quoted>$value</$attribute_quoted></TEMPLATE>",
                $template_xml
            );

        }
    }


}
