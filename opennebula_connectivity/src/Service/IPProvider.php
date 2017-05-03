<?php

namespace OneCS\Service;

use OneCS\Service\WHMCS\DatabaseManager;
use OneCS\Service\WHMCS\LocalAPI;

class IPProvider {

    const DB_TABLE = 'on_ips';

    private $db;

    public function __construct( DatabaseManager $db ) {
        $this->db = $db;
    }

    public function getAllIPs() {

        $ips = $this
            ->db
            ->getQueryBuilder( self::DB_TABLE )
            ->select()
            ->get();

        $services = array_map( function ( $row ) {

            $row = (array)$row;

            $row['tags'] = trim( $row['tags'] );
            $row['tags'] = empty( $row['tags'] )
                ? []
                : array_map( function ( $tag ) {
                    return strtolower( trim( $tag ) );
                }, explode( ',', $row['tags'] ) );

            $services = $this
                ->db
                ->getQueryBuilder('tblhosting')
                ->select(['id', 'userid'])
                ->where('dedicatedip', $row['IP'])
                ->get();

            $row['services'] = array_map( function ( $service ) {
                return (array)$service;
            }, $services );

            return $row;

        }, $ips );

        return $services;
    }

    public function addIP( $ip, array $tags = [] ) {

        $inserted = $this
            ->db
            ->getQueryBuilder( self::DB_TABLE )
            ->insert([
                'IP' => $ip,
                'tags' => implode( ',', array_map( 'strtolower', $tags ) ),
            ]);

        if( !$inserted ) {
            throw new \Exception('Fail to insert new IP');
        }
    }

    public function addIPRange( $ip_first, $amount, array $tags = [] ) {

        // TODO Add support of IPv6

        $matches = [];
        $s = [];
        if(
            !preg_match( '/^(?<S_3>\d{1,3})\.(?<S_2>\d{1,3})\.(?<S_1>\d{1,3})\.(?<S_0>\d{1,3})$/', $ip_first, $matches )
            || ( 0 > ( $s[0] = (int)$matches['S_0'] ) || $s[0] > 255 )
            || ( 0 > ( $s[1] = (int)$matches['S_1'] ) || $s[1] > 255 )
            || ( 0 > ( $s[2] = (int)$matches['S_2'] ) || $s[2] > 255 )
            || ( 0 > ( $s[3] = (int)$matches['S_3'] ) || $s[3] > 255 )
        ) {
            throw new \InvalidArgumentException('IP is not valid');
        }

        if( $amount < 1 ) {
            throw new \InvalidArgumentException('Amount is not valid');
        }

        do {
            $this->addIP( sprintf( '%d.%d.%d.%d', $s[3], $s[2], $s[1], $s[0] ), $tags );

            for( $p = 0; $p <= 4; $p++ ) {
                if( $s[ $p ] < 255 ) {
                    $s[ $p ]++;
                    break;
                }
                $s[ $p ] = 0;
            }
        } while( --$amount > 0 );
    }

    public function getFreeIP( array $tags = [] ) {

        foreach( $this->getAllIPs() as $ip_info ) {
            if(
                empty( $ip_info['services'] )
                &&
                (
                    empty( $tags )
                    ||
                    count( array_intersect( $tags, $ip_info['tags'] ) )
                )
            ) {
                return $ip_info['IP'];
            }
        }

        throw new \Exception('No free IPs left');
    }

}
