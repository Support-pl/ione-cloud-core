<?php


namespace OneCS\Service\WHMCS;

use Exception;


class LocalAPI {


    private $admin_id;


    public function __construct( $admin_id = null ) {
        $this->admin_id = $admin_id;
    }


    public function __call( $method, array $args ) {

        $method = strtolower( $method );
        $values = (array)@$args[0];

        $result = null === $this->admin_id
                ? localAPI( $method, $values )
                : localAPI( $method, $values, $this->admin_id );

        if( 'error' === $result['result'] ) {
            throw new Exception( $result['message'] );
        }

        return $result;
    }

}
