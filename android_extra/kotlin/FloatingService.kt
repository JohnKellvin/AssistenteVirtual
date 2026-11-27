package com.jarvis.jarvis_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView

/**
 * Janelinha flutuante: um ponto pequeno por cima de qualquer app.
 * Branco = Jarvis ativo. Cinza = stand-by. Tocar nele abre o Jarvis.
 * Pode ser arrastado pela tela.
 */
class FloatingService : Service() {
    private var wm: WindowManager? = null
    private var bolha: TextView? = null
    private var params: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val standby = intent?.getBooleanExtra("standby", false) ?: false
        val nome = intent?.getStringExtra("nome") ?: "Jarvis"
        iniciarComoPrimeiroPlano(nome)
        if (bolha == null) criarBolha()
        atualizar(standby, nome)
        return START_STICKY
    }

    private fun iniciarComoPrimeiroPlano(nome: String) {
        val canal = "jarvis_flutuante"
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(canal, "Janela do assistente", NotificationManager.IMPORTANCE_MIN))
        }
        val abrir = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(this, 0, abrir, PendingIntent.FLAG_IMMUTABLE)
        val n = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, canal) else Notification.Builder(this)
        val notificacao = n.setContentTitle(nome).setContentText("Janela ativa. Toque para abrir.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentIntent(pi).build()
        startForeground(7, notificacao)
    }

    private fun criarBolha() {
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val tipo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
        params = WindowManager.LayoutParams(
            140, 140, tipo,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 24; y = 260 }

        bolha = TextView(this).apply {
            gravity = Gravity.CENTER
            textSize = 11f
            setTextColor(Color.BLACK)
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.WHITE) }
        }
        var x0 = 0; var y0 = 0; var tx = 0f; var ty = 0f; var moveu = false
        bolha!!.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { x0 = params!!.x; y0 = params!!.y; tx = e.rawX; ty = e.rawY; moveu = false }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - tx).toInt(); val dy = (e.rawY - ty).toInt()
                    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) moveu = true
                    params!!.x = x0 + dx; params!!.y = y0 + dy
                    wm!!.updateViewLayout(v, params)
                }
                MotionEvent.ACTION_UP -> if (!moveu) {
                    val abrir = packageManager.getLaunchIntentForPackage(packageName)
                    abrir?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    startActivity(abrir)
                }
            }
            true
        }
        wm!!.addView(bolha, params)
    }

    private fun atualizar(standby: Boolean, nome: String) {
        val b = bolha ?: return
        (b.background as GradientDrawable).setColor(if (standby) Color.parseColor("#55FFFFFF") else Color.WHITE)
        b.text = if (standby) "zZ" else nome.take(1).uppercase()
    }

    override fun onDestroy() {
        bolha?.let { try { wm?.removeView(it) } catch (_: Exception) {} }
        bolha = null
        super.onDestroy()
    }
}
