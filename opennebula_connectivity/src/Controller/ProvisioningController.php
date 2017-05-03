<?php
namespace OneCS\Controller;

use TinyApp\Controller\AbstractController;
use Exception;

abstract class ProvisioningController extends AbstractController {


    /**
     * Get template of username for sprintf function
     * with placeholder for id.
     *
     * @return string template of username for sprintf function
     */
    protected abstract function getUsernameTemplate();


    protected function getUsernameByServiceID( $service_id ) {
        return sprintf( $this->getUsernameTemplate(), $service_id );
    }


    protected function getUserIDByName( $username ) {

        $users = $this
            ->get('one:client:helper')
            ->getAllUsers();

        if( !array_key_exists( $username, $users ) ) {
            throw new Exception( sprintf( 'User %s not found', $username ) );
        }

        return (int)$users[ $username ]['id'];
    }


    protected function getUserIDByServiceID( $service_id ) {
        $username = $this->getUsernameByServiceID( $service_id );
        return (int)$this->getUserIDByName( $username );
    }


    protected function doActionWithUserVMs( $user_id, $action ) {

        $exceptions = [];
        if ( is_array( $action ) ) {
            foreach( $action as $subaction ) {
                $subexceptions = $this->doActionWithUserVMs( $user_id, $subaction );
                $exceptions = array_merge($exceptions, $subexceptions);
            }
        }

        $user_vms = $this
            ->get('one:client:helper')
            ->getVMsOwnedBy( $user_id );

        $on = $this->get('one:client');

        foreach( $user_vms as $vm ) {
            try {
                $on->vmAction( $action, (int)$vm['ID'] );
            } catch( Exception $ex ) {
                $exceptions[] = $ex;
            }
        }

        return $exceptions;
    }


    protected function generatePassword() {

        $password = $this
            ->get('random:password')
            ->generate();

        return preg_replace( '/[\s\'"]/u', '_', $password );
    }


    /**
     * Get metadata of a provisioning module.
     */
    public abstract function metadataAction();


    /**
     * Define configuration of a provisioning module.
     */
    public abstract function defineConfigurationAction();


    /**
     * Suspend account.
     */
    public function suspendAccountAction( $service_id ) {
        try {

            $user_id = $this->getUserIDByServiceID( $service_id );

            $this
                ->get('one:client')
                ->userChauth( $user_id, 'disabled', '' );

            $this->doActionWithUserVMs( $user_id, 'suspend' );

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to suspend account due to unexpected error: '.$ex->getMessage();
        }
    }


    /**
     * Suspend account.
     */
    public function unsuspendAccountAction( $service_id ) {
        try {

            $user_id = $this->getUserIDByServiceID( $service_id );

            $this
                ->get('one:client')
                ->userChauth( $user_id, 'core', '' );

            $this->doActionWithUserVMs( $user_id, 'resume' );

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to unsuspend account due to unexpected error: '.$ex->getMessage();
        }
    }


    /**
     * Terminate account.
     */
    public function terminateAccountAction( $service_id ) {
        try {

            $user_id = $this->getUserIDByServiceID( $service_id );

            $this->doActionWithUserVMs( $user_id, ['poweroff-hard', 'undeploy-hard', 'delete'] );

            $this
                ->get('one:client')
                ->userDelete( $user_id );

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to delete account due to unexpected error: '.$ex->getMessage();
        }
    }


    /**
     * Change password.
     */
    public function changePasswordAction( $service_id ) {
        try {

            $user_id = $this->getUserIDByServiceID( $service_id );
            $password = $this->generatePassword();

            $users = $this
                ->get('one:client:helper')
                ->getAllUsers();

            $auth_driver = $users[ $user_id ]['auth_driver'];

            $this
                ->get('one:client')
                ->userChauth( $user_id, $auth_driver, $password );

            $this
                ->get('whmcs')
                ->updateClientProduct([
                    'serviceid' => $service_id,
                    'servicepassword' => $password,
                ]);

            return 'success';

        } catch( Exception $ex ) {
            return 'Unable to change password to the account due to unexpected error: '.$ex->getMessage();
        }
    }


    /**
     * Seamless authentication.
     */
    public function authAction( $username, $password ) {

//         $token = $this
//             ->get('one:client')
//             ->userLogin( $username, '', 86400 );

        $config = $this->get('config');

        $on_host = $config['host'];
        $on_ssl = $config['ssl'];

        $on_uri = ( $on_ssl ? 'https' : 'http' ).'://'.$on_host.'/';

        return [
            'username' => $username,
            'password' => $password,
            'token' => $token,
            'uri' => $on_uri,
        ];
    }


    /**
     * {@inheritDoc}
     *
     * @see \TinyApp\Controller\AbstractController::defineTemplates()
     */
    public function defineTemplates() {
        return [
            'auth' => 'auth_on',
        ];
    }


}
