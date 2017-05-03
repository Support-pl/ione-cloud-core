<?php
namespace OneCS;

use TinyApp\CApp;
use OneCS\Controller\DebugController;
use RandomLib\Factory as RandomLibFactory;
use PHPOneAPI\Client as PHPOneClient;
use OneCS\Service\ONClientHelper;
use OneCS\Service\PasswordGenerator;
use TinyApp\Service\RenderingEngine\DebugRenderingEngine;
use OneCS\Service\WHMCS\DatabaseManager;
use OneCS\Service\WHMCS\Config;
use OneCS\Controller\AdminController;
use OneCS\Controller\SetupController;
use OneCS\Controller\IaaSController;
use OneCS\Controller\PaaSController;
use OneCS\Service\WHMCS\LocalAPI;
use TinyApp\Service\Container;
use TinyApp\Service\RenderingEngine\PHPRenderingEngine;
use TinyApp\Service\RenderingEngine\MergedRenderingEngine;
use OneCS\Service\IPProvider;


class App extends CApp {

    private static $instance = null;


    /**
     * Use this class as a Singleton.
     *
     * @return \OneCS\App singleton instance of the class
     */
    public static function getInstance() {
        return self::$instance ?: self::$instance = new self();
    }


    protected function defineDependencies( Container $c ) {

        // Parameters

        $c['path:root'] = dirname( __DIR__ );

        $c['path:whmcs:root'] =
            dirname( // web root
                dirname( // modules
                    dirname( // addons
                        $c['path:root'] ) ) );

        $c['path:whmcs:modules'] = $c['path:whmcs:root'].DIRECTORY_SEPARATOR.'modules';
        $c['path:whmcs:modules:servers'] = $c['path:whmcs:modules'].DIRECTORY_SEPARATOR.'servers';
        $c['path:templates'] = $c['path:root'].DIRECTORY_SEPARATOR.'templates';

        // Controllers

        $c[self::CONTROLLER_PREFIX.'debug'] = function () {
            return new DebugController( $this );
        };

        $c[self::CONTROLLER_PREFIX.'setup'] = function () {
            return new SetupController( $this );
        };

        $c[self::CONTROLLER_PREFIX.'iaas'] = function () {
            return new IaaSController( $this );
        };

        $c[self::CONTROLLER_PREFIX.'paas'] = function () {
            return new PaaSController( $this );
        };


        // Rendering engine


        $c[self::RENDERING_ENGINE_KEY] = function ( $c ) {

            $engine_php = new PHPRenderingEngine();
            $engine_debug = new DebugRenderingEngine();
            $engine_merged = new MergedRenderingEngine( [ $engine_php, $engine_debug ] );

            $engine_php->addTemplateDirectories( $c['path:root'].DIRECTORY_SEPARATOR.'templates' );

            return $engine_merged;
        };


        // Services

        $c['random:factory'] = function () {
            return new RandomLibFactory();
        };

        $c['random:low'] = function ( $c ) {
            return $c['random:factory']->getLowStrengthGenerator();
        };

        $c['random:medium'] = function ( $c ) {
            return $c['random:factory']->getMediumStrengthGenerator();
        };

        $c['random:password'] = function( $c ) {
            return new PasswordGenerator( $c['random:medium'] );
        };


        $c['one:client'] = function ( $c ) {

            $config = $c['config'];

            return new PHPOneClient(
                $config['username'],
                $config['password'],
                $config['host'],
                (bool)$config['ssl'],
                (int)$config['port'],
                $config['path']
            );
        };


        $c['one:client:helper'] = function ( $c ) {
            return new ONClientHelper( $c['one:client'] );
        };

        $c['database'] = function () {
            return new DatabaseManager();
        };

        $c['config'] = function ( $c ) {
            return new Config( $c['database'] );
        };


        $c['whmcs:full_admin_id'] = function ( $c ) {

            $db = $c['database'];

            $roles = $db
                ->getQueryBuilder('tbladminroles')
                ->where('name', 'Full Administrator')
                ->orderBy('id', 'asc')
                ->take(1)
                ->get([ 'id' ]);

            $role_id = $roles[0]->id;

            $admins = $db
                ->getQueryBuilder('tbladmins')
                ->where('roleid', $role_id)
                ->orderBy('id', 'asc')
                ->take(1)
                ->get([ 'id' ]);

            return $admins[0]->id;
        };


        $c['whmcs'] = function ( $c ) {
            return new LocalAPI( $c['whmcs:full_admin_id'] );
        };

        // TODO register services

    }

}