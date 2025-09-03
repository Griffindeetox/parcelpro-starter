// --- Append to your src/routes/api.php ---

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\OrderController;

Route::post('/orders', [OrderController::class, 'store']);
Route::get('/health/ready', [OrderController::class, 'ready']);
