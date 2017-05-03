<?php
namespace OneCS\Controller;

use TinyApp\Controller\AbstractController;
use Exception;

class SetupController extends AbstractController {


    const PROVISIONING_MODULE_IAAS = 'opennebulaiaas';
    const PROVISIONING_MODULE_PAAS = 'opennebulapaas';


    /**
     * Define configuration of the addon module.
     */
    public function defineConfigurationAction() {
        return $this
            ->get('config')
            ->getDefinition();
    }


    /**
     * Activate the addon module.
     */
    public function activateAction() {
        try {

            // setup additional modules

            $paths = $this->getPaths();

            $data_iaas = "<?php require '{$paths['path_root']}/modules/servers/opennebulaiaas/module.php';\n";
            $data_paas = "<?php require '{$paths['path_root']}/modules/servers/opennebulapaas/module.php';\n";

            (
                mkdir( $paths['dir_iaas'] )
                &&
                mkdir( $paths['dir_paas'] )
            )
                || $this->ex( sprintf( 'Unable to create directories: %s, %s.', $paths['dir_iaas'], $paths['dir_paas'] ) );

            (
                file_put_contents( $paths['file_iaas'], $data_iaas )
                &&
                file_put_contents( $paths['file_paas'], $data_paas )
            )
                || $this->ex( sprintf( 'Unable to create files: %s, %s.', $paths['file_iaas'], $paths['file_paas'] ) );

            return [
                'status' => 'success',
                'description' => 'Module have been successfully activated.',
            ];

        } catch( Exception $ex ) {
            return [
                'status' => 'error',
                'description' => $ex->getMessage(),
            ];
        }
    }


    /**
     * Deactivate the addon module.
     */
    public function deactivateAction() {
        try {

            $paths = $this->getPaths();

            (
                $this->rm( $paths['dir_iaas'] )
                &&
                $this->rm( $paths['dir_paas'] )
            )
                || $this->ex( sprintf( 'Unable to remove directories: %s, %s.', $paths['dir_iaas'], $paths['dir_paas'] ) );


            return [
                'status' => 'success',
                'description' => 'Module have been successfully deactivated.',
            ];

        } catch( Exception $ex ) {
            return [
                'status' => 'error',
                'description' => $ex->getMessage(),
            ];
        }
    }


    private function getPaths() {

        $path_root = $this->get('path:root');

        $path_modules_servers = $this->get('path:whmcs:modules:servers');
        $module_name_iaas = self::PROVISIONING_MODULE_IAAS;
        $module_name_paas = self::PROVISIONING_MODULE_PAAS;

        $dir_iaas = $path_modules_servers.DIRECTORY_SEPARATOR.$module_name_iaas;
        $dir_paas = $path_modules_servers.DIRECTORY_SEPARATOR.$module_name_paas;

        $file_iaas = $dir_iaas.DIRECTORY_SEPARATOR.$module_name_iaas.'.php';
        $file_paas = $dir_paas.DIRECTORY_SEPARATOR.$module_name_paas.'.php';

        return [
            'path_root' => $path_root,
            'path_modules_servers' => $path_modules_servers,
            'module_name_iaas' => $module_name_iaas,
            'module_name_paas' => $module_name_paas,
            'dir_iaas' => $dir_iaas,
            'dir_paas' => $dir_paas,
            'file_iaas' => $file_iaas,
            'file_paas' => $file_paas,
        ];
    }


    private function ex( $message ) {
        throw new Exception( $message );
    }


    private function rm( $path ) {
        if( is_dir( $path ) ) {
            $success = true;
            foreach( scandir( $path ) as $subpath ) {
                if( '.' === $subpath || '..' === $subpath ) {
                    continue;
                }
                $success = $this->rm( $subpath ) && $success;
            }
            return rmdir( $path ) && $success;
        }
        return unlink( $path );
    }


}