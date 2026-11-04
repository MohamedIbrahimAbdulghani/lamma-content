<?php
// Lamma - by Mohamed Ibrahim

use App\Http\Controllers\Api\V1\BootstrapController;
use App\Http\Controllers\Api\V1\ContentGenerationController;
use App\Http\Controllers\Api\V1\ContentHistoryController;
use App\Http\Controllers\Api\V1\ContentReportController;
use App\Http\Controllers\Api\V1\ContentSyncController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\QuestionController;
use App\Http\Controllers\Api\V1\RoomContentController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware(['throttle:60,1'])->group(function () {
    Route::get('/health', [HealthController::class, 'health']);
    Route::get('/ai/health', [HealthController::class, 'aiHealth']);
    Route::get('/bootstrap', [BootstrapController::class, 'bootstrap']);
    Route::get('/content/version', [BootstrapController::class, 'version']);

    // الأسئلة والمخزون
    Route::get('/questions', [QuestionController::class, 'index']);
    Route::post('/questions/seen', [QuestionController::class, 'markSeen']);
    Route::get('/questions/stock', [QuestionController::class, 'stock']);

    // جلسات الغرف وإدارة المحتوى الذاتي الآمن
    Route::post('/rooms', [RoomContentController::class, 'createRoom']);
    Route::post('/rooms/{roomCode}/join', [RoomContentController::class, 'joinRoom']);
    Route::post('/rooms/{roomCode}/leave', [RoomContentController::class, 'leaveRoom']);
    Route::get('/rooms/{roomCode}/next-question', [RoomContentController::class, 'getNextQuestion']);
    Route::get('/rooms/{roomCode}/next-questions-batch', [RoomContentController::class, 'getNextQuestionsBatch']);
    Route::post('/rooms/{roomCode}/grade-question', [RoomContentController::class, 'gradeQuestion']);
    Route::get('/rooms/{roomCode}/next-spy-round', [RoomContentController::class, 'getNextSpyRound']);
    Route::get('/rooms/{roomCode}/next-spy-batch', [RoomContentController::class, 'getNextSpyBatch']);
    Route::get('/rooms/{roomCode}/next-charades', [RoomContentController::class, 'getNextCharades']);
    Route::get('/rooms/{roomCode}/next-charades-batch', [RoomContentController::class, 'getNextCharadesBatch']);

    // البلاغات ومزامنة المحتوى
    Route::post('/content/report', [ContentReportController::class, 'report']);
    Route::get('/content/sync-status', [ContentSyncController::class, 'syncStatus']);
    Route::post('/content/sync-history', [ContentSyncController::class, 'syncHistory']);

    Route::post('/content/generate', [ContentGenerationController::class, 'generate']);
    Route::post('/history/reset', [ContentHistoryController::class, 'reset']);
});
