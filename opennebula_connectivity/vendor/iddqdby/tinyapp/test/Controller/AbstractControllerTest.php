<?php


/**
 * @coversDefaultClass TinyApp\Controller\AbstractController
 */
class AbstractControllerTest extends \PHPUnit_Framework_TestCase {


    /**
     * @test
     * @covers ::get
     * @uses \TinyApp\App
     */
    public function test_get() {

        $obj = new \stdClass();

        $mock_app = $this
            ->getMockBuilder( '\\TinyApp\\App' )
            ->enableAutoload()
            ->setMethods( [
                'get'
            ] )
            ->getMockForAbstractClass();

        $mock_app
            ->method( 'get' )
            ->will( $this->returnValueMap( [
                [ 'foo', $obj ],
            ] ) );

        $controller = $this
            ->getMockBuilder( '\\TinyApp\\Controller\\AbstractController' )
            ->enableAutoload()
            ->setConstructorArgs( [ $mock_app ] )
            ->setMethods( [
                'testAction'
            ] )
            ->getMockForAbstractClass();

        $test_action = function () {
            return $this->get( 'foo' );
        };

        $controller
            ->method( 'testAction' )
            ->will( $this->returnCallback( $test_action->bindTo( $controller, get_class( $controller ) ) ) );

        $obj_result = $controller->testAction();

        $this->assertSame( $obj, $obj_result );

    }

}
