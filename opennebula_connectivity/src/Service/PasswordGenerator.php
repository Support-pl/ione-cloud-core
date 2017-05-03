<?php


namespace OneCS\Service;

use RandomLib\Generator;


class PasswordGenerator {

    private $generator;


    public function __construct( Generator $generator ) {
        $this->generator = $generator;
    }


    public function generate( $length = 16 ) {
        return $this
            ->generator
            ->generateString(
                $length,
                  Generator::CHAR_UPPER
                | Generator::CHAR_LOWER
                | Generator::CHAR_DIGITS
                | Generator::CHAR_SYMBOLS
            );
    }


}
