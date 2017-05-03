<?php

namespace TinyApp\Controller;


/* Mock for function php_sapi_name */

function php_sapi_name() {
    return php_sapi_name_setup();
}

function php_sapi_name_setup( $name_new = null ) {
    static $name = 'cli';
    return null === $name_new
        ? $name
        : $name = $name_new;
}

/* End of mock for function php_sapi_name */


/**
 * @coversDefaultClass \TinyApp\Controller\CLIController
 */
class CLIControllerTest extends \PHPUnit_Framework_TestCase {


    /**
     * @test
     * @covers ::__construct
     * @uses \TinyApp\App
     * @dataProvider php_sapi_name_provider
     * @expectedException \RuntimeException
     * @expectedExceptionMessage Controller can be invoked only from CLI
     */
    public function test_construct_exception( $sapi_name ) {

        php_sapi_name_setup( $sapi_name );

        $mock_app = $this->getMockForAbstractClass( '\\TinyApp\\App' );

        $controller = $this
            ->getMockBuilder( '\\TinyApp\\Controller\\CLIController' )
            ->disableOriginalConstructor()
            ->getMockForAbstractClass();

        $controller->__construct( $mock_app );
    }


    /**
     * @test
     * @covers ::__construct
     * @covers ::stdout
     * @covers ::stderr
     * @uses \TinyApp\App
     */
    public function test_construct() {

        php_sapi_name_setup( 'cli' );

        $mock_app = $this
            ->getMockBuilder( '\\TinyApp\\App' )
            ->setMethods( [
                'stdout',
                'stderr',
            ] )
            ->getMockForAbstractClass();

        $mock_app
            ->expects( $this->once() )
            ->method( 'stdout' )
            ->with( $this->equalTo( 'foo' ) );

        $mock_app
            ->expects( $this->once() )
            ->method( 'stderr' )
            ->with( $this->equalTo( 'bar' ) );

        $controller = $this
            ->getMockBuilder( '\\TinyApp\\Controller\\CLIController' )
            ->disableOriginalConstructor()
            ->setMethods( [
                'testAction',
            ] )
            ->getMockForAbstractClass();

        $test_action = function () {
            $this->stdout( 'foo' );
            $this->stderr( 'bar' );
        };

        $controller
            ->method( 'testAction' )
            ->will( $this->returnCallback(
                $test_action->bindTo( $controller, get_class( $controller ) )
            ) );

        $controller->__construct( $mock_app );
        $controller->testAction();
    }


    public function php_sapi_name_provider() {
        return [
            [ 'apache' ],
            [ 'cgi-fcgi' ],
            [ 'cli-server' ],
            [ 'continuity' ],
            [ 'embed' ],
            [ 'nsapi' ],
            [ 'phttpd' ],
            [ 'pi3web' ],
            [ 'roxen' ],
            [ 'thttpd' ],
        ];
    }

}
