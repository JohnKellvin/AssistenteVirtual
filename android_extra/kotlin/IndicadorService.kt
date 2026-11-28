package com.jarvis.jarvis_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.Icon
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Indicador fixo do assistente: uma notificação em primeiro plano.
 * Em estilo de player de mídia (cartão com arte, título e botões) ou simples.
 * Botões: Falar, Stand-by/Acordar e Encerrar.
 */
class IndicadorService : Service() {
    companion object {
        const val CANAL = "assistente_indicador"
        const val ID = 7
        const val ACAO_STANDBY = "com.jarvis.jarvis_android.STANDBY"
        const val ACAO_ENCERRAR = "com.jarvis.jarvis_android.ENCERRAR"
    }

    private var nome = "Assistente"
    private var estado = "ativo"
    private var midia = true
    private var sessao: MediaSession? = null

    private val arteAtiva: Bitmap by lazy { desenharEsfera(false) }
    private val arteApagada: Bitmap by lazy { desenharEsfera(true) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACAO_STANDBY -> alternarStandby()
            ACAO_ENCERRAR -> {
                MainActivity.canalJanela?.invokeMethod("encerrar", null)
                encerrar()
                return START_NOT_STICKY
            }
            else -> {
                nome = intent?.getStringExtra("nome") ?: nome
                estado = intent?.getStringExtra("estado") ?: estado
                midia = intent?.getBooleanExtra("midia", true) ?: true
            }
        }
        publicar()
        return START_NOT_STICKY
    }

    private fun alternarStandby() {
        estado = if (estado == "standby") "ativo" else "standby"
        MainActivity.canalJanela?.invokeMethod("standby", estado == "standby")
    }

    private fun encerrar() {
        liberarSessao()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun intentAbrir(acao: String?): Intent {
        val i = packageManager.getLaunchIntentForPackage(packageName) ?: Intent()
        i.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        )
        if (acao != null) i.putExtra("acao", acao)
        return i
    }

    private fun acao(titulo: String, icone: Int, pi: PendingIntent): Notification.Action =
        Notification.Action.Builder(Icon.createWithResource(this, icone), titulo, pi).build()

    private fun publicar() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(CANAL, "Indicador do assistente", NotificationManager.IMPORTANCE_LOW)
            canal.setShowBadge(false)
            canal.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(canal)
        }

        val standby = estado == "standby"
        val texto = when (estado) {
            "standby" -> "Stand-by · toque em acordar"
            "ouvindo" -> "Ouvindo…"
            "pensando" -> "Pensando…"
            "falando" -> "Falando…"
            else -> "Ativo · toque para falar"
        }
        val imut = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val abrir = PendingIntent.getActivity(this, 0, intentAbrir(null), imut)
        val falar = PendingIntent.getActivity(this, 2, intentAbrir("falar"), imut)
        val alternar = PendingIntent.getService(
            this, 1, Intent(this, IndicadorService::class.java).setAction(ACAO_STANDBY), imut
        )
        val fechar = PendingIntent.getService(
            this, 3, Intent(this, IndicadorService::class.java).setAction(ACAO_ENCERRAR), imut
        )

        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CANAL)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(nome)
            .setContentText(texto)
            .setContentIntent(abrir)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setLargeIcon(if (standby) arteApagada else arteAtiva)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            b.setColor(Color.parseColor(if (standby) "#3A3A3A" else "#8A3B0F"))
            b.setColorized(true)
        }

        var botoes = 0
        if (standby) {
            b.addAction(acao("Acordar", android.R.drawable.ic_btn_speak_now, alternar)); botoes++
        } else {
            b.addAction(acao("Falar", android.R.drawable.ic_btn_speak_now, falar)); botoes++
            b.addAction(acao("Stand-by", android.R.drawable.ic_lock_power_off, alternar)); botoes++
        }
        b.addAction(acao("Encerrar", android.R.drawable.ic_menu_close_clear_cancel, fechar)); botoes++

        if (midia && !standby) {
            val s = sessao ?: criarSessao().also { sessao = it }
            atualizarSessao(s, texto)
            b.setStyle(
                Notification.MediaStyle()
                    .setMediaSession(s.sessionToken)
                    .setShowActionsInCompactView(*IntArray(botoes) { it })
            )
        } else {
            liberarSessao()
        }

        val n = b.build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID, n)
        }
    }

    private fun criarSessao(): MediaSession {
        val s = MediaSession(this, "assistente")
        s.setCallback(object : MediaSession.Callback() {
            override fun onCustomAction(action: String, extras: Bundle?) {
                when (action) {
                    "standby" -> { alternarStandby(); publicar() }
                    "encerrar" -> {
                        MainActivity.canalJanela?.invokeMethod("encerrar", null)
                        encerrar()
                    }
                    "falar" -> abrirParaFalar()
                }
            }

            override fun onPlay() = abrirParaFalar()
        })
        s.isActive = true
        return s
    }

    // Pode ser bloqueado pelo Android se o app estiver em segundo plano; nesse caso, toque no cartão.
    private fun abrirParaFalar() {
        try {
            startActivity(intentAbrir("falar"))
        } catch (_: Exception) {
        }
    }

    private fun atualizarSessao(s: MediaSession, texto: String) {
        s.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, nome)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, texto)
                .putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, arteAtiva)
                .build()
        )
        val trabalhando = estado == "ouvindo" || estado == "falando" || estado == "pensando"
        s.setPlaybackState(
            PlaybackState.Builder()
                .setActions(0L)
                .setState(
                    if (trabalhando) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                    1f
                )
                .addCustomAction(PlaybackState.CustomAction.Builder("falar", "Falar", android.R.drawable.ic_btn_speak_now).build())
                .addCustomAction(PlaybackState.CustomAction.Builder("standby", "Stand-by", android.R.drawable.ic_lock_power_off).build())
                .addCustomAction(PlaybackState.CustomAction.Builder("encerrar", "Encerrar", android.R.drawable.ic_menu_close_clear_cancel).build())
                .build()
        )
    }

    private fun liberarSessao() {
        sessao?.let {
            it.isActive = false
            it.release()
        }
        sessao = null
    }

    // Esfera de pontos desenhada na hora, usada como a "capa" do cartão.
    private fun desenharEsfera(apagada: Boolean): Bitmap {
        val t = 256
        val bmp = Bitmap.createBitmap(t, t, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(Color.parseColor(if (apagada) "#222222" else "#14100C"))
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val n = 420
        val rot = 0.9f
        val incl = 0.42f
        for (i in 0 until n) {
            val y = 1f - (i / (n - 1f)) * 2f
            val r = sqrt(1f - y * y)
            val th = i * 2.39996f
            val x0 = cos(th) * r
            val z0 = sin(th) * r
            val x1 = x0 * cos(rot) + z0 * sin(rot)
            val z1 = -x0 * sin(rot) + z0 * cos(rot)
            val y1 = y * cos(incl) - z1 * sin(incl)
            val z2 = y * sin(incl) + z1 * cos(incl)
            val prof = (z2 + 1.3f) / 2.6f
            p.color = Color.WHITE
            p.alpha = (255 * (0.15f + 0.85f * prof * prof)).toInt().coerceIn(20, 255)
            c.drawCircle(t / 2f + x1 * 96f, t / 2f + y1 * 96f, 1.2f + 1.6f * prof, p)
        }
        return bmp
    }

    override fun onDestroy() {
        liberarSessao()
        super.onDestroy()
    }
}
