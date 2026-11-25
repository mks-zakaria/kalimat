package com.zakaria.crossword.ads

import android.app.Activity
import com.google.android.play.core.review.ReviewManagerFactory

/** Google Play's in-app rating card. Play decides whether it really shows (it has its own limits). */
object Review {
    fun ask(activity: Activity) {
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
        }
    }
}
