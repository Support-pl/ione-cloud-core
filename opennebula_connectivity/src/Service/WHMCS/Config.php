<?php
namespace OneCS\Service\WHMCS;

use ArrayAccess;
use IteratorAggregate;
use ArrayIterator;


/**
 * Module configuration holder.
 *
 * WARNIG: values CANNOT be modified in foreach loop.
 */
class Config implements ArrayAccess, IteratorAggregate {

    /** Name of the addon module */
    const MODULE_NAME = 'opennebula_connectivity';

    private static $table = 'tbladdonmodules';

    private $db;
    private $values = null;


    /**
     * Create new instance of config.
     *
     * @param DatabaseManager $db
     */
    public function __construct( DatabaseManager $db ) {
        $this->db = $db;
    }


    /**
     * Get definition of this addon module configuration.
     *
     * @return array definition of this addon module configuration
     */
    public function getDefinition() {
        return [
            'name' => 'OpenNebula Connectivity addon',
            'description' => 'Manage VMs in OpenNebula through WHMCS',
            'version' => '0.2',
            'author' => 'Sergey Protasevich <sergey.p@gmx.com>',
            'fields' => [
                'username' => [
                    'FriendlyName' => 'Username',
                    'Type' => 'text',
                    'Size' => 64,
                    'Description' => '<br>Username of OpenNebula admin',
                    'Default' => '',
                ],
                'password' => [
                    'FriendlyName' => 'Password',
                    'Type' => 'password',
                    'Size' => 64,
                    'Description' => '<br>Password of OpenNebula admin',
                    'Default' => '',
                ],
                'host' => [
                    'FriendlyName' => 'Host',
                    'Type' => 'text',
                    'Size' => 64,
                    'Description' => '<br>Host of OpenNebula XML-RPC API',
                    'Default' => '',
                ],
                'port' => [
                    'FriendlyName' => 'Port',
                    'Type' => 'text',
                    'Size' => 8,
                    'Description' => '<br>Port of OpenNebula XML-RPC API',
                    'Default' => '2633',
                ],
                'path' => [
                    'FriendlyName' => 'Path',
                    'Type' => 'text',
                    'Size' => 64,
                    'Description' => '<br>Path of OpenNebula XML-RPC API',
                    'Default' => 'RPC2',
                ],
                'ssl' => [
                    'FriendlyName' => 'SSL',
                    'Type' => 'yesno',
                    'Description' => 'Whether to use or not to use HTTPS',
                    'Default' => 'on',
                ],
            ],
        ];
    }


    /**
     * @return \Illuminate\Database\Query\Builder
     */
    private function qb() {
        return $this->db->getQueryBuilder( self::$table );
    }


    private function fetchValues() {

        if( null !== $this->values ) {
            return;
        }

        $values_raw = $this
            ->qb()
            ->where( 'module', self::MODULE_NAME )
            ->get( [
                'setting',
                'value'
            ] );

        $values = [];
        foreach( $values_raw as $value_raw ) {
            $values[ $value_raw->setting ] = $value_raw->value;
        }

        $this->values = $values;
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetExists()
     */
    public function offsetExists( $offset ) {
        $this->fetchValues();
        return array_key_exists( $offset, $this->values );
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetGet()
     */
    public function offsetGet( $offset ) {
        $this->fetchValues();
        return $this->values[ $offset ];
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetSet()
     */
    public function offsetSet( $offset, $value ) {

        $this->fetchValues();

        if( array_key_exists( $offset, $this->values ) ) {

            $this
                ->qb()
                ->where( 'module', self::MODULE_NAME )
                ->where( 'setting', $offset )
                ->update([
                    'value' => $value,
                ]);

        } else {

            $this
                ->qb()
                ->insert([
                    'module' => self::MODULE_NAME,
                    'setting' => $offset,
                    'value' => $value,
                ]);

        }

        $this->values[ $offset ] = $value;

        return $value;
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetUnset()
     */
    public function offsetUnset( $offset ) {

        $this->fetchValues();

        $this
            ->qb()
            ->where( 'module', self::MODULE_NAME )
            ->where( 'setting', $offset )
            ->delete();

        unset( $this->values[ $offset ] );
    }


    public function __get( $offset ) {
        return $this[ $offset ];
    }


    public function __set( $offset, $value ) {
        return $this[ $offset ] = $value;
    }


    public function __isset( $offset ) {
        return isset( $this[ $offset ] );
    }


    public function __unset( $offset ) {
        unset( $this[ $offset ] );
    }


    /**
     * {@inheritDoc}
     *
     * @see IteratorAggregate::getIterator()
     */
    public function getIterator() {
        $this->fetchValues();
        $values_copy = $this->values;
        return new ArrayIterator( $values_copy );
    }

}
