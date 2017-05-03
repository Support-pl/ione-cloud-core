<?php


namespace OneCS\Controller;

use OneCS\Controller\ProvisioningController;
use Exception;


class IaaSController extends ProvisioningController {


    /**
     * {@inheritDoc}
     *
     * @see \OneCS\Controller\ProvisioningController::getUsernameTemplate()
     */
    protected function getUsernameTemplate() {
        return 'user_iaas_%s';
    }


    protected function getGroupNameByServiceID( $service_id ) {
        return sprintf( 'iaas_%s', $service_id );
    }


    /**
     * Metadata of the IaaS provisioning module.
     */
    public function metadataAction() {
        return [
            'DisplayName' => 'OpenNebula IaaS',
            'RequiresServer' => true,
        ];
    }


    /**
     * Define configuration for IaaS product.
     */
    public function defineConfigurationAction() {
        return [
            'tariff_name' => [ // configoption1
                'FriendlyName' => 'Tariff name',
                'Type' => 'text',
                'Size' => 16,
                'Description' => 'Allowed characters: lowercase letters, underscore, digits.'
            ],
            'vm_template' => [ // configoption2
                'FriendlyName' => 'VM limit (amount)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 8,
            ],
            'limit_cpu' => [ // configoption3
                'FriendlyName' => 'CPU limit (amount)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 16,
            ],
            'limit_ram' => [ // configoption4
                'FriendlyName' => 'RAM limit (MB)',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 20480,
            ],
            'limit_hdd' => [ // configoption5
                'FriendlyName' => 'HDD limit (GB) [10 GB is minimum]',
                'Type' => 'text',
                'Size' => 8,
                'Default' => 100.,
            ],
        ];
    }


    /**
     * Create IaaS account.
     */
    public function createAccountAction( $service_id, $tariff_name, $limit_vm, $limit_cpu, $limit_ram, $limit_hdd ) {
        try {

            // generate username
            $username = $this->getUsernameByServiceID( $service_id );

            // generate group name
            $group_name = $this->getGroupNameByServiceID( $service_id );

            // generate password
            $password = $this->generatePassword();

            // get OpenNebula client
            $on = $this->get('one:client');

            // allocate new user
            $user_id = $on->userAllocate( $username, $password, '' );

            // allocate new group
            $group_id_own = $on->groupAllocate( $group_name );

            // set groups for the user

            $group_pool_info = $this
                ->get('one:client:helper')
                ->getAllGroups();

            $group_id_iaas = $group_pool_info['iaas']['id'];
            $group_id_users = $group_pool_info['users']['id'];
            $group_id_tariff = @$group_pool_info[ $tariff_name ]['id'];

            if( !$group_id_tariff ) {
                $group_id_tariff = $on->groupAllocate( $tariff_name );
            }

            $on->userChgrp( $user_id, $group_id_own );
            $on->userAddgroup( $user_id, $group_id_iaas );
            $on->userAddgroup( $user_id, $group_id_tariff );
            $on->userAddgroup( $user_id, $group_id_users );

            // set limits for the own group of the user

            $limit_vm = intval( $limit_vm );
            $limit_cpu = intval( $limit_cpu );
            $limit_ram = intval( $limit_ram );

            $limit_hdd = intval( (float)$limit_hdd * 1024 ); // GB -> MB
            if( $limit_hdd < 10 * 1024 ) {
                $limit_hdd = 10 * 1024;
            }

            $on->groupQuota( $group_id_own, preg_replace( '/\s+/u', '', "
                <VM_QUOTA>
                    <VM>
                        <CPU><![CDATA[$limit_cpu]]></CPU>
                        <MEMORY><![CDATA[$limit_ram]]></MEMORY>
                        <SYSTEM_DISK_SIZE><![CDATA[$limit_hdd]]></SYSTEM_DISK_SIZE>
                        <VMS><![CDATA[$limit_vm]]></VMS>
                    </VM>
                </VM_QUOTA>
            " ) );

            // make user an admin of the own group

            $on->groupAddadmin( $group_id_own, $user_id );

            // set all permissions

            // TODO Set all permissions for IaaS

            // save username and password of the instance of a product

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


    /**
     * {@inheritDoc}
     *
     * @see \OneCS\Controller\ProvisioningController::suspendAccountAction()
     */
    public function suspendAccountAction( $service_id ) {
        try {

            $result = parent::suspendAccountAction( $service_id );

            if( 'success' !== $result ) {
                throw new Exception( $result );
            }

            $on = $this->get('one:client');
            $on_helper = $this->get('one:client:helper');

            $group_name = $this->getGroupNameByServiceID( $service_id );
            $group_pool_info = $on_helper->getAllGroups();

            if( !array_key_exists( $group_name, $group_pool_info ) ) {
                throw new Exception( sprintf( 'Group %s not found', $group_name ) );
            }

            $group_id = (int)$group_pool_info[ $group_name ]['id'];
            $users_from_group = $on_helper->getUsersFromGroup( $group_id );

            foreach( $users_from_group as $subuser ) {
                $subuser_id = $subuser['id'];
                $on->userChauth( $subuser_id, 'disabled', '' );
                $this->doActionWithUserVMs( $subuser_id, 'suspend' );
            }

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to suspend account due to unexpected error: '.$ex->getMessage();
        }
    }


    /**
     * {@inheritDoc}
     *
     * @see \OneCS\Controller\ProvisioningController::unsuspendAccountAction()
     */
    public function unsuspendAccountAction( $service_id ) {
        try {

            $result = parent::unsuspendAccountAction( $service_id );

            if( 'success' !== $result ) {
                throw new Exception( $result );
            }

            $on = $this->get('one:client');
            $on_helper = $this->get('one:client:helper');

            $group_name = $this->getGroupNameByServiceID( $service_id );
            $group_pool_info = $on_helper->getAllGroups();

            if( !array_key_exists( $group_name, $group_pool_info ) ) {
                throw new Exception( sprintf( 'Group %s not found', $group_name ) );
            }

            $group_id = (int)$group_pool_info[ $group_name ]['id'];
            $users_from_group = $on_helper->getUsersFromGroup( $group_id );

            foreach( $users_from_group as $subuser ) {
                $subuser_id = $subuser['id'];
                $on->userChauth( $subuser_id, 'core', '' );
                $this->doActionWithUserVMs( $subuser_id, 'resume' );
            }

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to unsuspend account due to unexpected error: '.$ex->getMessage();
        }
    }


    /**
     * {@inheritDoc}
     *
     * @see \OneCS\Controller\ProvisioningController::terminateAccountAction()
     */
    public function terminateAccountAction( $service_id ) {
        try {

            $result = parent::terminateAccountAction( $service_id );

            if( 'success' !== $result ) {
                throw new Exception( $result );
            }

            $on = $this->get('one:client');
            $on_helper = $this->get('one:client:helper');

            $group_name = $this->getGroupNameByServiceID( $service_id );
            $group_pool_info = $on_helper->getAllGroups();

            if( !array_key_exists( $group_name, $group_pool_info ) ) {
                throw new Exception( sprintf( 'Group %s not found', $group_name ) );
            }

            $group_id = (int)$group_pool_info[ $group_name ]['id'];
            $users_from_group = $on_helper->getUsersFromGroup( $group_id );

            foreach( $users_from_group as $subuser ) {
                $subuser_id = $subuser['id'];
                $this->doActionWithUserVMs( $subuser_id, 'delete' );
                $on->userDelete( $subuser_id );
            }

            $on->groupDelete( $group_id );

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to delete account due to unexpected error: '.$ex->getMessage();
        }
    }


}
