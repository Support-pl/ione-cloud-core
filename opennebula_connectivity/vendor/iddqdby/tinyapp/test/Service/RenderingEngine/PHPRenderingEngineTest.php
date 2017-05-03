<?php


use TinyApp\Service\RenderingEngine\PHPRenderingEngine;

/**
 * @coversDefaultClass \TinyApp\Service\RenderingEngine\PHPRenderingEngine
 */
class PHPRenderingEngineTest extends \PHPUnit_Framework_TestCase {

    private static $error_reporting;

    public static function setUpBeforeClass() {
        self::$error_reporting = error_reporting( 0 );
    }

    public static function tearDownAfterClass() {
        error_reporting( self::$error_reporting );
    }


    /**
     * @test
     * @dataProvider error_types
     * @covers ::__construct
     * @covers ::doRender
     */
    public function test_doRender( $error_types, array $template_expectations ) {

        $engine = null === $error_types
            ? new PHPRenderingEngine()
            : new PHPRenderingEngine( $error_types );

        $engine->addTemplateDirectories( TEST_DIR_ROOT.'/'.TEST_DIR_TEMPLATES.'/php' );
        $engine->setTemplatePrefix( 'template_' );

        $data = 'bar';

        $expected_exception_class = '\\TinyApp\\Exception\\TemplateException';
        $expected_exception_message_regex = '/Unexpected exception while rendering template .+/u';
        $expected_exception_previous_class = '\\TinyApp\\Exception\\TemplateException';
        $expected_exception_previous_message_regex = '/Unexpected error while rendering template .+.php\\. Error: \\d+ .+. File: .+:\\d+./u';

        foreach( $template_expectations as $template => $expectations ) {

            $ex_expected = $expectations[0];
            $string_expected = $expectations[1];

            try {

                $result = $engine->render( $data, $template );

                if( $ex_expected ) {
                    $this->fail( 'Expected exception not thrown: '.$template );
                }
                $this->assertEquals( $string_expected, $result );

            } catch( \PHPUnit_Framework_AssertionFailedError $ex ) {
                throw $ex;
            } catch( \Exception $ex ) {

                if( !$ex_expected ) {
                    $this->fail( 'Exception must not be thrown: '.$template );
                }

                $this->assertInstanceOf( $expected_exception_class, $ex );
                $this->assertRegExp( $expected_exception_message_regex, $ex->getMessage() );

                $ex_previous = $ex->getPrevious();

                if( 'error' === $template && preg_match( '/^7\\./', phpversion() ) ) {
                    $this->assertInstanceOf( '\\TypeError', $ex_previous );
                } else {
                    $this->assertInstanceOf( $expected_exception_previous_class, $ex_previous );
                    $this->assertRegExp( $expected_exception_previous_message_regex, $ex_previous->getMessage() );
                }
            }
        }

    }


    public function error_types() {
        return [
            'all' => [
                null,
                [
                    'good'      => [ false, 'bar|null' ],
                    'notice'    => [ true, null ],
                    'warning'   => [ true, null ],
                    'error'     => [ true, null ],
                ]
            ],
            'all except E_NOTICE' => [
                E_ALL & ~E_NOTICE,
                [
                    'good'      => [ false, 'bar|null' ],
                    'notice'    => [ false, 'foo ' ],
                    'warning'   => [ true, null ],
                    'error'     => [ true, null ],
                ]
            ],
            'all except E_NOTICE and E_WARNING' => [
                E_ALL & ~E_NOTICE & ~E_WARNING,
                [
                    'good'      => [ false, 'bar|null' ],
                    'notice'    => [ false, 'foo ' ],
                    'warning'   => [ false, 'baz ' ],
                    'error'     => [ true, null ],
                ]
            ],
            'all except E_WARNING' => [
                E_ALL & ~E_WARNING,
                [
                    'good'      => [ false, 'bar|null' ],
                    'notice'    => [ true, null ],
                    'warning'   => [ false, 'baz ' ],
                    'error'     => [ true, null ],
                ]
            ],
        ];
    }


}
