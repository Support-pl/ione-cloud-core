<?php


namespace OneCS\Controller;

use TinyApp\Controller\AbstractController; // vendor/iddqdby/tinyapp


class AdminController extends AbstractController {

    public function outputAction( $submit_type, $tags, $ip, $amount ) {

        $data = [];

        $tags = trim( $tags ); //Удаление из строки пробелов и др символов из начала и конца строки
        $tags = empty( $tags ) //Проверка на пустую строку
            ? [] //Задается массив
            : array_map( function ( $tag ) { //array_map возвращает массив(второй аргумент) обработанный функцией tag
                return strtolower( trim( $tag ) );
            }, explode( ',', $tags ) ); //Аналог split

        $ip_provider = $this->get('provider:ip'); //Вызов IPProvider.php для добавления адреса в пул

        try {
            switch( $submit_type ) { //Определение количества запрошенных адресов
                case 'single':
                    $ip_provider->addIP( $ip, $tags ); //Добавление адреса в пул
                    break;
                case 'range':
                    $ip_provider->addIPRange( $ip, intval( $amount ), $tags ); //Добавление диапазона адресов в пул
                    break;
                default:
                    if( 'POST' === $_SERVER['REQUEST_METHOD'] ) { //Исключение на неправильное поле $submit_type
                        throw new \Exception('Invalid form data submitted!');
                    }
            }
        } catch( \Exception $ex ) { //Обработка исключения
            $data['error'] = $ex->getMessage();
        }

        $ips = $ip_provider->getAllIPs(); //Получение всего пула адресов
        foreach( $ips as &$ip_info ) {
            sort( $ip_info['tags'] ); //Сортировка по полю 'tags'
            $ip_info['tags'] = implode( ',', $ip_info['tags'] ); //Создание строки из массива
        }
        unset( $ip_info ); //Удаление переменной $ip_info

        usort( $ips, function ( array $ip_1, array $ip_2 ) { //Аналог qsort
            return strcasecmp( $ip_1['tags'], $ip_2['tags'] ); //Сравнение строк без учета регистра
        } );

        $data['IPs'] = []; //Объявление словаря $data с полем IPs
        foreach( $ips as $ip_info ) {
            $data['IPs'][] = [
                'tags' => $ip_info['tags'], //Иморт полей tags IP и service_uris
                'IP' => $ip_info['IP'],
                'service_uris' => implode( ',<br>', array_map( function ( $service ) {
                    return '<a href="/admin/clientsservices.php?userid='.$service['userid'].'&id='.$service['id'].'" target="_blank">'.$service['id'].'</a>';
                }, $ip_info['services'] ) ),
            ];
        }

        return $data;
    }

    public function defineTemplates() { //Определение шаблона
        return [
            'output' => 'ip_table',
        ];
    }

}
