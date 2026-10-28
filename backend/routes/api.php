<?php
// Lamma - by Mohamed Ibrahim

use App\Http\Controllers\Api\V1\BootstrapController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\QuestionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware(['throttle:60,1'])->group(function () {
    Route::get('/health', [HealthController::class, 'health']);
    Route::get('/bootstrap', [BootstrapController::class, 'bootstrap']);
    Route::get('/content/version', [BootstrapController::class, 'version']);

    Route::get('/questions', [QuestionController::class, 'index']);
    Route::post('/questions/seen', [QuestionController::class, 'markSeen']);
    Route::get('/questions/stock', [QuestionController::class, 'stock']);
});
