<?php

namespace OneCS\Service;

use OneCS\Service\WHMCS\DatabaseManager;
use OneCS\Service\WHMCS\LocalAPI;

class IPProvider {

    const DB_TABLE = 'on_ips';

    private $db;

    public function __construct( DatabaseManager $db ) { //Класс из Service/WHMCS/DatabaseManager.php
        $this->db = $db;
    }

    public function getAllIPs() {

        $ips = $this
            ->db //Обращение к пулу адресов 
            ->getQueryBuilder( self::DB_TABLE ) //Конструктор запросов, параметр - база данных
            ->select() //Фиксация
            ->get(); //Запись таблицы адресов для ON в $ips

        $services = array_map( function ( $row ) { //Получение свободных адресов по UserID

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
                ->where('dedicatedip', $row['IP']) //Получение выделенного адреса из tblhosting
                ->get();

            $row['services'] = array_map( function ( $service ) {
                return (array)$service;
            }, $services );

            return $row;

        }, $ips );

        return $services;
    }

    public function addIP( $ip, array $tags = [] ) { //Добавление адреса в таблицу адресов ON

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

    public function addIPRange( $ip_first, $amount, array $tags = [] ) { //Добавление диапазона адресов в таблицу

        // TODO Add support of IPv6

        $matches = [];
        $s = [];
        if( //Проверка на соответствие regexp, проверяющему валидность ip-адреса IPv4
            !preg_match( '/^(?<S_3>\d{1,3})\.(?<S_2>\d{1,3})\.(?<S_1>\d{1,3})\.(?<S_0>\d{1,3})$/', $ip_first, $matches )
            || ( 0 > ( $s[0] = (int)$matches['S_0'] ) || $s[0] > 255 )
            || ( 0 > ( $s[1] = (int)$matches['S_1'] ) || $s[1] > 255 )
            || ( 0 > ( $s[2] = (int)$matches['S_2'] ) || $s[2] > 255 )
            || ( 0 > ( $s[3] = (int)$matches['S_3'] ) || $s[3] > 255 )
        ) {
            throw new \InvalidArgumentException('IP is not valid'); //В случае несоответсвия regexp
        }

        if( $amount < 1 ) {
            throw new \InvalidArgumentException('Amount is not valid'); //В случае неправильно заданного количества
        }

        do {
            $this->addIP( sprintf( '%d.%d.%d.%d', $s[3], $s[2], $s[1], $s[0] ), $tags ); //Добавление адреса поодиночке

            for( $p = 0; $p <= 4; $p++ ) {
                if( $s[ $p ] < 255 ) {
                    $s[ $p ]++;
                    break;
                }
                $s[ $p ] = 0;
            }
        } while( --$amount > 0 );
    }

    public function getFreeIP( array $tags = [] ) { //Получение свободного адреса

        foreach( $this->getAllIPs() as $ip_info ) { //Запись всех адресов в $ip_info
            if(
                empty( $ip_info['services'] ) //Проверка на пустоту пула
                &&
                (
                    empty( $tags ) //Проверка на отсутствие тегов
                    ||
                    count( array_intersect( $tags, $ip_info['tags'] ) ) //Count считает количество рекурсивных вызовов
//    а array_intersect удаляет все вхождения элементов $ip_info['tags'] в $tags
                )
            ) {
                return $ip_info['IP']; //Если все условия валидности выполняются возвращается список свободных адресов $ip_info['IP']
            }
        }

        throw new \Exception('No free IPs left'); //Если if не выполнится, т.е. одно из условий нарушится, будет сгенерировано исключение _NO_FREE_IP_LEFT
    }
}
