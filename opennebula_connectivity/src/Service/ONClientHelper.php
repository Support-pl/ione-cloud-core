<?php


namespace OneCS\Service;


use PHPOneAPI\Client;
use SimpleXMLElement;


class ONClientHelper {

    private $client;


    /**
     * Create new client helper.
     *
     * @param Client $client the instance of client
     */
    public function __construct( Client $client ) {
        $this->client = $client;
    }


    /**
     * Get all datastores.
     *
     * @return array datastores
     */
    public function getAllDatastores() {

        $datastores_raw = $this->client->datastorepoolInfo();

        $datastores = simplexml_load_string( $datastores_raw, null, LIBXML_NOCDATA );
        $datastores_raw_array = $this->objectToArray( $datastores );
        $datastores_array = [];

        foreach ($datastores_raw_array['DATASTORE'] as $datastore) {

            $datastore_id = $datastore['ID'];
            $datastore_name = $datastore['NAME'];

            $datastores_array[(int) $datastore_id] = $datastores_array[$datastore_name] = $datastore;
        }

        return $datastores_array;
    }


    /**
     * Get all groups.
     *
     * @return array groups
     */
    public function getAllGroups() {

        $group_pool_info_raw = $this
            ->client
            ->grouppoolInfo();

        $group_pool_info = new SimpleXMLElement(
                "<?xml version='1.0' standalone='yes'?>"
                .$group_pool_info_raw );

        $group_pool_info_array = [];

        foreach( $group_pool_info->GROUP as $group ) {

            $group_id = (int)$group->ID;
            $group_name = (string)$group->NAME;

            $group_pool_info_array[ $group_id ] = $group_pool_info_array[ $group_name ] = [
                'id' => $group_id,
                'name' => $group_name,
                'template' => array_keys( (array)$group->TEMPLATE ),
                'users' => (array)$group->USERS->ID,
                'admins' => (array)$group->ADMINS->ID,
            ];
        }

        return $group_pool_info_array;
    }


    /**
     * Get all users.
     *
     * @return array users
     */
    public function getAllUsers() {

        $user_pool_info_raw = $this
            ->client
            ->userpoolInfo();

        $user_pool_info = new SimpleXMLElement(
                "<?xml version='1.0' standalone='yes'?>"
                .$user_pool_info_raw );

        $user_pool_info_array = [];

        foreach( $user_pool_info->USER as $user ) {

            $user_id = (int)$user->ID;
            $user_name = (string)$user->NAME;

            $user_pool_info_array[ $user_id ] = $user_pool_info_array[ $user_name ] = [
                'id' => $user_id,
                'name' => $user_name,
                'gid' => (int)$user->GID,
                'gname' => (string)$user->GNAME,
                'groups' => (array)$user->GROUPS->ID,
                'enabled' => (bool)$user->ENABLED,
                'auth_driver' => (string)$user->AUTH_DRIVER,
            ];
        }

        return $user_pool_info_array;
    }


    /**
     * Get users from given group.
     *
     * @param int $group_id group ID
     * @return array users
     */
    public function getUsersFromGroup( $group_id ) {

        $group_id = intval( $group_id );

        $users_all = $this->getAllUsers();
        $users_from_group = [];

        foreach( $users_all as $user ) {
            if( $group_id == $user['gid'] || in_array( $group_id, $user['groups'] ) ) {
                $users_from_group[ $user['id'] ] = $user;
            }
        }

        return $users_from_group;
    }


    /**
     * Get all VM templates.
     *
     * @return array VM templates
     */
    public function getAllTemplates() {

        $template_info_raw = $this
            ->client
            ->templatepoolInfo( -1, -1, -1 );

        $template_info = simplexml_load_string( $template_info_raw, null, LIBXML_NOCDATA );
        $template_info_array_raw = $this->objectToArray( $template_info );

        $template_info_array = [];

        foreach( $template_info_array_raw['VMTEMPLATE'] as $template ) {

            $template['_XML'] = $template_info_raw;

            $template_info_array[ (int)$template['ID'] ]
                    = $template_info_array[ $template['NAME'] ]
                    = $template;
        }

        return $template_info_array;
    }


    /**
     * Get VMs owned by given user.
     *
     * @param int $user_id user ID
     * @return array info about VMs
     */
    public function getVMsOwnedBy( $user_id ) {

        $user_id = intval( $user_id );

        $vm_info_raw = $this
            ->client
            ->vmpoolInfo( -2, -1, -1, -2 );

        $vm_info = simplexml_load_string( $vm_info_raw, null, LIBXML_NOCDATA );
        $vm_info_array_all = $this->objectToArray( $vm_info );

        $vm_info_array = [];

        foreach( $vm_info_array_all['VM'] as $vm ) {
            if( $user_id === intval( $vm['UID'] ) ) {
                $vm_info_array[ $vm['ID'] ] = $vm;
            }
        }

        return $vm_info_array;
    }


    private function objectToArray( $var ) {

//        if( $var instanceof \Traversable ) {
//            $var = iterator_to_array( $var, true );
//        }

        if( is_object( $var ) ) {
            $var = (array)$var;
        }

        if( is_array( $var ) ) {
            $var_converted = [];
            foreach( $var as $key => $subvar ) {
                $var_converted[ $key ] = $this->objectToArray( $subvar );
            }
            $var = $var_converted;
        }

        return $var;
    }


}
