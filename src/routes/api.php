<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\OrderController;

Route::get('/ping', fn () => response()->json(['pong' => true], 200));

Route::post('/orders', [OrderController::class, 'store']);
Route::get('/health/ready', [OrderController::class, 'ready']);
