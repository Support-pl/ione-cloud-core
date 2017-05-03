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

namespace TinyApp\Service;

use ArrayAccess;
use BadMethodCallException;
use OutOfBoundsException;
use LogicException;


/**
 * Dependency injection container.
 */
class Container implements ArrayAccess {

    private $definitions = [];

    private $instances = [];

    private $called = [];


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetSet()
     */
    public function offsetSet( $offset, $value ) {
        $this->checkPresence( $offset );
        return is_callable( $value )
            ? $this->definitions[ $offset ] = $value
            : $this->instances[ $offset ] = $value;
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetExists()
     */
    public function offsetExists( $offset ) {
        return array_key_exists( $offset, $this->definitions )
                || array_key_exists( $offset, $this->instances );
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetGet()
     */
    public function offsetGet( $offset ) {

        if( array_key_exists( $offset, $this->instances ) ) {
            return $this->instances[ $offset ];
        }

        if( array_key_exists( $offset, $this->definitions ) ) {

            if( isset( $this->called[ $offset ] ) ) {
                throw new LogicException( sprintf( 'Recursion in dependencies detected: key "%s"', $offset ) );
            }

            $this->called[ $offset ] = true;
            $instance = $this->instances[ $offset ] = $this->definitions[ $offset ]( $this );

            unset( $this->definitions[ $offset ] );
            unset( $this->called[ $offset ] );

            return $instance;
        }

        throw new OutOfBoundsException( sprintf( 'Key "%s" is not defined', $offset ) );
    }


    /**
     * {@inheritDoc}
     *
     * @see ArrayAccess::offsetUnset()
     */
    public function offsetUnset( $offset ) {
        $this->checkPresence( $offset );
        unset( $this->definitions[ $offset ] );
    }


    private function checkPresence( $offset ) {
        if( array_key_exists( $offset, $this->instances ) ) {
            throw new BadMethodCallException( sprintf( 'Key "%s" has already been set', $offset ) );
        }
    }


}
