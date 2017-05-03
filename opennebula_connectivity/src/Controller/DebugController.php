<?php
namespace OneCS\Controller;

use TinyApp\Controller\CLIController;


class DebugController extends CLIController {


    public function defineTemplates() {
        return [
            'onDatastores' => 'tree',
            'getExtVersion' => 'plain',
            'createUser' => 'tree',
            'getUserInfo' => 'plain',
            'getAllUsers' => 'tree',
            'setUserStatus' => 'tree',
            'generateNewPassword' => 'tree',
            'deleteUser' => 'tree',
            'authUser' => 'tree',
        ];
    }


    /**
     * Get all datastores on OpenNebula
     */
    public function onDatastoresAction() {
        return $this
            ->get('one:client:helper')
            ->getAllDatastores();

        /*
         * <DATASTORE>
         *      <ID>107</ID>
         *      <UID>2</UID>
         *      <GID>0</GID>
         *      <UNAME>CloudAdmin</UNAME>
         *      <GNAME>oneadmin</GNAME>
         *      <NAME>NAS1-1</NAME>
         *      <PERMISSIONS>
         *          <OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>0</OWNER_A><GROUP_U>1</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>0</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A>
         *      </PERMISSIONS>
         *      <DS_MAD><![CDATA[vcenter]]></DS_MAD>
         *      <TM_MAD><![CDATA[vcenter]]></TM_MAD>
         *      <BASE_PATH><![CDATA[/var/lib/one//datastores/107]]></BASE_PATH>
         *      <TYPE>0</TYPE>
         *      <DISK_TYPE>0</DISK_TYPE>
         *      <STATE>0</STATE>
         *      <CLUSTERS>
         *          <ID>100</ID>
         *      </CLUSTERS>
         *      <TOTAL_MB>3689368</TOTAL_MB>
         *      <FREE_MB>2066685</FREE_MB>
         *      <USED_MB>1622683</USED_MB>
         *      <IMAGES></IMAGES>
         *      <TEMPLATE>
         *          <CLONE_TARGET><![CDATA[NONE]]></CLONE_TARGET>
         *          <DISK_TYPE><![CDATA[FILE]]></DISK_TYPE>
         *          <DS_MAD><![CDATA[vcenter]]></DS_MAD>
         *          <LABELS><![CDATA[FastNAS]]></LABELS>
         *          <LN_TARGET><![CDATA[NONE]]></LN_TARGET>
         *          <RESTRICTED_DIRS><![CDATA[/]]></RESTRICTED_DIRS>
         *          <SAFE_DIRS><![CDATA[/var/tmp]]></SAFE_DIRS>
         *          <TM_MAD><![CDATA[vcenter]]></TM_MAD>
         *          <TYPE><![CDATA[IMAGE_DS]]></TYPE>
         *          <VCENTER_CLUSTER><![CDATA[vOne]]></VCENTER_CLUSTER>
         *      </TEMPLATE>
         * </DATASTORE>
         *
         * <DATASTORE>
         *      <ID>106</ID>
         *      <UID>2</UID>
         *      <GID>0</GID>
         *      <UNAME>CloudAdmin</UNAME>
         *      <GNAME>oneadmin</GNAME>
         *      <NAME>NAS3</NAME>
         *      <PERMISSIONS>
         *          <OWNER_U>1</OWNER_U>
         *          <OWNER_M>1</OWNER_M>
         *          <OWNER_A>0</OWNER_A>
         *          <GROUP_U>1</GROUP_U>
         *          <GROUP_M>0</GROUP_M>
         *          <GROUP_A>0</GROUP_A>
         *          <OTHER_U>0</OTHER_U>
         *          <OTHER_M>0</OTHER_M>
         *          <OTHER_A>0</OTHER_A>
         *      </PERMISSIONS>
         *      <DS_MAD><![CDATA[vcenter]]></DS_MAD>
         *      <TM_MAD><![CDATA[vcenter]]></TM_MAD>
         *      <BASE_PATH><![CDATA[/var/lib/one//datastores/106]]></BASE_PATH>
         *      <TYPE>0</TYPE>
         *      <DISK_TYPE>0</DISK_TYPE>
         *      <STATE>0</STATE>
         *      <CLUSTERS>
         *          <ID>100</ID>
         *      </CLUSTERS>
         *      <TOTAL_MB>993207</TOTAL_MB>
         *      <FREE_MB>927306</FREE_MB>
         *      <USED_MB>65901</USED_MB>
         *      <IMAGES></IMAGES>
         *      <TEMPLATE>
         *          <CLONE_TARGET><![CDATA[NONE]]></CLONE_TARGET>
         *          <DISK_TYPE><![CDATA[FILE]]></DISK_TYPE>
         *          <DS_MAD><![CDATA[vcenter]]></DS_MAD>
         *          <LN_TARGET><![CDATA[NONE]]></LN_TARGET>
         *          <RESTRICTED_DIRS><![CDATA[/]]></RESTRICTED_DIRS>
         *          <SAFE_DIRS><![CDATA[/var/tmp]]></SAFE_DIRS>
         *          <TM_MAD><![CDATA[vcenter]]></TM_MAD>
         *          <VCENTER_CLUSTER><![CDATA[vOne]]></VCENTER_CLUSTER>
         *      </TEMPLATE>
         * </DATASTORE>
         */
    }


    /**
     * Generate authentication token for a user.
     */
    public function authUserAction( $user_id, $valid = 86400 ) {

        $users = $this
            ->get('one:client:helper')
            ->getAllUsers();

        $user_name = $users[ $user_id ]['name'];

        return $this
            ->get('one:client')
            ->userLogin( $user_name, '', (int)$valid );
    }


    /**
     * Delete user.
     */
    public function deleteUserAction( $user_id ) {
        return $this
            ->get('one:client')
            ->userDelete( (int)$user_id );
    }


    /**
     * Generate new password for a user.
     */
    public function generateNewPasswordAction( $user_id ) {

        $user_id = (int)$user_id;

        $password = $this
            ->get('random:password')
            ->generate();

        $users = $this
            ->get('one:client:helper')
            ->getAllUsers();

        $auth_driver = $users[ $user_id ]['auth_driver'];

        $this
            ->get('one:client')
            ->userChauth( $user_id, $auth_driver, $password );

        return [
            'user_id' => $user_id,
            'new password' => $password,
        ];
    }


    /**
     * Set user status (enabled, disabled).
     */
    public function setUserStatusAction( $user_id, $status ) {
        return $this
            ->get('one:client')
            ->userChauth( (int)$user_id, (int)$status ? 'core' : 'disabled', '' );
    }


    /**
     * Get list of all users;
     */
    public function getAllUsersAction() {
        return $this
            ->get('one:client:helper')
            ->getAllUsers();
    }


    /**
     * Get user info.
     */
    public function getUserInfoAction( $user_id ) {
        return $this
            ->get('one:client')
            ->userInfo( (int)$user_id );
    }


    /**
     * Create user.
     */
    public function createUserAction( $username, $type = null, $cpu_limit = 0, $ram_limit = 0, $hdd_limit = 0 ) {

        $on = $this->get('one:client');

        $group_pool_info = $this
            ->get('one:client:helper')
            ->getAllGroups();

        $group_id_paas = $group_pool_info['paas']['id'];
        $group_id_iaas = $group_pool_info['iaas']['id'];
        $group_id_users = $group_pool_info['users']['id'];

        $password = $this
            ->get('random:password')
            ->generate();

        $password = str_replace( ' ', '_', $password );

        $user_id = $on->userAllocate( $username, $password, '' );

        $vm_limit = -1; // default
        switch( strtolower( $type ) ) {
            case 'paas':
                $on->userChgrp( $user_id, $group_id_paas );
                $vm_limit = 1;
                break;
            case 'iaas':
                $on->userChgrp( $user_id, $group_id_iaas );
                $vm_limit = -2; // unlimited
                break;
        }
        $on->userAddgroup( $user_id, $group_id_users );

        $quota = <<<QUOTA
<VM_QUOTA>
    <VM>
        <CPU><![CDATA[$cpu_limit]]></CPU>
        <MEMORY><![CDATA[$ram_limit]]></MEMORY>
        <SYSTEM_DISK_SIZE><![CDATA[$hdd_limit]]></SYSTEM_DISK_SIZE>
        <VMS><![CDATA[$vm_limit]]></VMS>
    </VM>
</VM_QUOTA>
QUOTA;
        $quota = preg_replace( '/\s+/u', '', $quota );

        $on->userQuota( $user_id, $quota );

        $user_info = $on->userInfo( $user_id );

        return [
            'username' => $username,
            'password' => $password,
            'user_id' => $user_id,
            'info' => $user_info,
        ];

//         array (
//             'username' => 'test_user_2_paas',
//             'password' => '7?+dP4V;9S!j/1D(',
//             'user_id' => 12,
//             'info' => '
//     <USER>
//         <ID>12</ID>
//         <GID>101</GID>
//         <GROUPS>
//             <ID>1</ID>
//             <ID>101</ID>
//         </GROUPS>
//         <GNAME>users</GNAME>
//         <NAME>test_user_2_paas</NAME>
//         <PASSWORD>e02139773c7554f2f9efefefe7605816e79cd821</PASSWORD>
//         <AUTH_DRIVER>core</AUTH_DRIVER>
//         <ENABLED>1</ENABLED>
//         <LOGIN_TOKEN/>
//         <TEMPLATE>
//             <TOKEN_PASSWORD><![CDATA[4381e08623adb24272bdb84a325d6ec7ffcf71e0]]></TOKEN_PASSWORD>
//         </TEMPLATE>
//         <DATASTORE_QUOTA></DATASTORE_QUOTA>
//         <NETWORK_QUOTA></NETWORK_QUOTA>
//         <VM_QUOTA></VM_QUOTA>
//         <IMAGE_QUOTA></IMAGE_QUOTA>
//         <DEFAULT_USER_QUOTAS>
//             <DATASTORE_QUOTA></DATASTORE_QUOTA>
//             <NETWORK_QUOTA></NETWORK_QUOTA>
//             <VM_QUOTA></VM_QUOTA>
//             <IMAGE_QUOTA></IMAGE_QUOTA>
//         </DEFAULT_USER_QUOTAS>
//     </USER>
//                 ',
//         );

//         array (
//             'username' => 'test_user_3_iaas',
//             'password' => 'fPbo`sPRvn+aP&|a',
//             'user_id' => 13,
//             'info' => '
//     <USER>
//         <ID>13</ID>
//         <GID>100</GID>
//         <GROUPS>
//             <ID>1</ID>
//             <ID>100</ID>
//         </GROUPS>
//         <GNAME>users</GNAME>
//         <NAME>test_user_3_iaas</NAME>
//         <PASSWORD>1a00059c229fc273f7aecc94d9e1ca8b8c67f6ba</PASSWORD>
//         <AUTH_DRIVER>core</AUTH_DRIVER>
//         <ENABLED>1</ENABLED>
//         <LOGIN_TOKEN/>
//         <TEMPLATE>
//             <TOKEN_PASSWORD><![CDATA[8e8e801ce501fc72586df5a0255a19f94618045d]]></TOKEN_PASSWORD>
//         </TEMPLATE>
//         <DATASTORE_QUOTA></DATASTORE_QUOTA>
//         <NETWORK_QUOTA></NETWORK_QUOTA>
//         <VM_QUOTA></VM_QUOTA>
//         <IMAGE_QUOTA></IMAGE_QUOTA>
//         <DEFAULT_USER_QUOTAS>
//             <DATASTORE_QUOTA></DATASTORE_QUOTA>
//             <NETWORK_QUOTA></NETWORK_QUOTA>
//             <VM_QUOTA></VM_QUOTA>
//             <IMAGE_QUOTA></IMAGE_QUOTA>
//         </DEFAULT_USER_QUOTAS>
//     </USER>
//                 ',
//         );
    }


    /**
     * Get version of PHP extension.
     */
    public function getExtVersionAction( $name ) {
        $refl = new \ReflectionExtension( $name );
        return $refl->getVersion();
    }


}