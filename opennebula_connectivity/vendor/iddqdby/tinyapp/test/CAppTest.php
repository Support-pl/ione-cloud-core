<?php

use TinyApp\Service\Container;


/**
 * @coversDefaultClass TinyApp\CApp
 */
class CAppTest extends \PHPUnit_Framework_TestCase {


    /**
     * @test
     * @covers ::get
     * @uses \TinyApp\Service\Container
     */
    public function test_get() {

        $app = $this
            ->getMockBuilder( '\\TinyApp\\CApp' )
            ->enableAutoload()
            ->disableOriginalConstructor()
            ->setMethods( [
                'defineDependencies'
            ] )
            ->getMockForAbstractClass();

        $app
            ->method( 'defineDependencies' )
            ->will( $this->returnCallback( function ( Container $c ) {
                $c['foo'] = 'bar';
            } ) );

        $app->__construct();

        $result = $app->get( 'foo' );
        $this->assertEquals( 'bar', $result );

    }

}