<?php

/*
 * The MIT License
 *
 * Copyright 2016 Sergey Protasevich.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

namespace TinyApp\Service\RenderingEngine;


/**
 * Rendering engine intended to be used for debugging purposes.
 *
 * Template direcroties are ignored. The only valid values for $template argument
 * of render() method are: var_export, var_dump, tree, plain.
 */
class DebugRenderingEngine implements IRenderingEngine {


    private $tree_string_length;


    /**
     * Create instance of rendering engine.
     *
     * @param int $tree_string_length max length of strings for tree output
     * (longer strings will be truncated) (optional, default is 64)
     */
    public function __construct( $tree_string_length = 64 ) {
        $this->tree_string_length = $tree_string_length;
    }


    /**
     * {@inheritDoc}
     *
     * Valid values for $template are: var_export, var_dump, tree, plain.
     *
     * @see \TinyApp\Service\RenderingEngine\IRenderingEngine::render()
     */
    public function render( $data, $template ) {
        switch( $template ) {
            case 'var_export':
                return var_export( $data, true );
            case 'var_dump':
                ob_start();
                var_dump( $data );
                return ob_get_clean();
            case 'plain':
                return strval( $data );
            case 'tree':
            default:
                return $this->tree( 'root', $data );
        }
    }


    private function tree( $key, $value, $gap = '' ) {
        $string = $this->pair( $key, $value );
        if( is_array( $value ) ) {
            $i = 0;
            $v_count = count( $value );
            $v_max = $v_count - 1;
            foreach( $value as $sub_key => $sub_value ) {
                $is_last = $i++ === $v_max;
                $indention = '  '.preg_replace( '/./u', ' ', $key.$v_count );
                $prefix = $gap.$indention.' ';
                $string .= PHP_EOL.$prefix.( $is_last ? '└' : '├' )
                        .$this->tree( $sub_key, $sub_value, $prefix.( $is_last ? ' ' : '│' ) );
            }
        }
        return $string;
    }


    private function pair( $key, $value ) {
        switch( $type = strtolower( gettype( $value ) ) ) {
            case 'null':
                return sprintf( ' %s => [null]', $key );
            case 'boolean':
                return sprintf( ' %s => [bool] %s', $key, $value ? 'true' : 'false' );
            case 'integer':
                return sprintf( ' %s => [int] %s', $key, $value );
            case 'double':
                return sprintf( ' %s => [float] %s', $key, $value );
            case 'string':
                return sprintf( ' %s => [string(%s)] "%s"',
                    $key,
                    $strlen = mb_strlen( $value, 'UTF-8' ),
                    $this->tree_string_length >= $strlen
                        ? $value
                        : ( mb_substr( $value, 0, $this->tree_string_length ).'...' )
                );
            case 'array':
                return empty( $value )
                    ? sprintf( ' %s[0]', $key )
                    : sprintf( ' %s[%s]┐', $key, count( $value ) );
            case 'object':
                $string = '';
                if( method_exists( $value, '__toString' ) ) {
                    $value_str = (string)$value;
                    if( $this->tree_string_length >= mb_strlen( $value, 'UTF-8' ) ) {
                        $string = ' "'.$value_str.'"';
                    } else {
                        $string = ' "'.mb_substr( $value_str, 0, $this->tree_string_length, 'UTF-8' )
                                .'..." (truncated, '.mb_strlen( $value_str, 'UTF-8' ).' chars total)';
                    }
                } elseif( $value instanceof \DateTime ) {
                    $string = ' "'.$value->format('Y-m-d H:i:s').'"';
                }
                return sprintf( ' %s => [%s]%s', $key, get_class( $value ), $string );
            default:
                return sprintf( ' %s => [%s]', $key, $type );
        }
    }


    /**
     * This method does nothing. It is a stub.
     *
     * @return this
     */
    public function setTemplatePrefix( $prefix ) {
        return $this;
    }


    /**
     * This method returns empty string. It is a stub.
     *
     * @return string empty string
     */
    public function getTemplatePrefix() {
        return '';
    }


    /**
     * This method does nothing. It is a stub.
     *
     * @return this
     */
    public function setTemplatePostfix( $postfix ) {
        return $this;
    }


    /**
     * This method returns empty string. It is a stub.
     *
     * @return string empty string
     */
    public function getTemplatePostfix() {
        return '';
    }


    /**
     * This method does nothing. It is a stub.
     *
     * @return this
     */
    public function addTemplateDirectories( $dirs ) {
        return $this;
    }


    /**
     * This method does nothing. It is a stub.
     *
     * @return this
     */
    public function removeTemplateDirectories( $dirs ) {
        return $this;
    }


    /**
     * This method returns empty array. It is a stub.
     *
     * @return array empty array
     */
    public function getTemplateDirectories() {
        return [];
    }

}
