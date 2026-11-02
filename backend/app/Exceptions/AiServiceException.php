<?php
// Lamma - by Mohamed Ibrahim

namespace App\Exceptions;

class AiServiceException extends \RuntimeException
{
    public function __construct(
        string $message,
        private readonly int $statusCode = 500,
        private readonly string $errorCode = 'AI_ERROR',
        private readonly ?array $debugInfo = null
    ) {
        parent::__construct($message, $statusCode);
    }

    public function getStatusCode(): int
    {
        return $this->statusCode;
    }

    public function getErrorCode(): string
    {
        return $this->errorCode;
    }

    public function getDebugInfo(): ?array
    {
        return $this->debugInfo;
    }
}
