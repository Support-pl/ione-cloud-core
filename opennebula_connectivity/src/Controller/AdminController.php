<?php


namespace OneCS\Controller;

use TinyApp\Controller\AbstractController;


class AdminController extends AbstractController {

    public function outputAction( $submit_type, $tags, $ip, $amount ) {

        $data = [];

        $tags = trim( $tags );
        $tags = empty( $tags )
            ? []
            : array_map( function ( $tag ) {
                return strtolower( trim( $tag ) );
            }, explode( ',', $tags ) );

        $ip_provider = $this->get('provider:ip');

        try {
            switch( $submit_type ) {
                case 'single':
                    $ip_provider->addIP( $ip, $tags );
                    break;
                case 'range':
                    $ip_provider->addIPRange( $ip, intval( $amount ), $tags );
                    break;
                default:
                    if( 'POST' === $_SERVER['REQUEST_METHOD'] ) {
                        throw new \Exception('Invalid form data submitted!');
                    }
            }
        } catch( \Exception $ex ) {
            $data['error'] = $ex->getMessage();
        }

        $ips = $ip_provider->getAllIPs();
        foreach( $ips as &$ip_info ) {
            sort( $ip_info['tags'] );
            $ip_info['tags'] = implode( ',', $ip_info['tags'] );
        }
        unset( $ip_info );

        usort( $ips, function ( array $ip_1, array $ip_2 ) {
            return strcasecmp( $ip_1['tags'], $ip_2['tags'] );
        } );

        $data['IPs'] = [];
        foreach( $ips as $ip_info ) {
            $data['IPs'][] = [
                'tags' => $ip_info['tags'],
                'IP' => $ip_info['IP'],
                'service_uris' => implode( ',<br>', array_map( function ( $service ) {
                    return '<a href="/admin/clientsservices.php?userid='.$service['userid'].'&id='.$service['id'].'" target="_blank">'.$service['id'].'</a>';
                }, $ip_info['services'] ) ),
            ];
        }

        return $data;
    }

    public function defineTemplates() {
        return [
            'output' => 'ip_table',
        ];
    }

}
