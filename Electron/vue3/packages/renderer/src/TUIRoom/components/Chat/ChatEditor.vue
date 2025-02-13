<template>
  <div
    :class="['chat-editor', cannotSendMessage ? 'disable-editor': '']"
  >
    <textarea
      ref="editorInputEle"
      v-model="sendMsg"
      class="content-bottom-input"
      :disabled="cannotSendMessage"
      :placeholder="cannotSendMessage ? t('Muted by the moderator') : t('Type a message')"
      @keyup.enter="sendMessage"
    />
    <div v-if="!cannotSendMessage" class="chat-editor-toolbar">
      <div class="left-section">
        <emoji @choose-emoji="handleChooseEmoji"></emoji>
      </div>
      <div :class="['send-btn', `${sendMsg.length > 0 ? 'active' : ''}`]" @click="sendMessage">{{ t('Send') }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { ElMessage } from '../../elementComp';

import useGetRoomEngine from '../../hooks/useRoomEngine';
import { useChatStore } from '../../stores/chat';
import { useRoomStore } from '../../stores/room';
import emoji from './EditorTools/emoji.vue';
import { useI18n } from '../../locales';

const roomEngine = useGetRoomEngine();

const { t } = useI18n();
const chatStore = useChatStore();
const roomStore = useRoomStore();

const { isMessageDisableByAdmin } = storeToRefs(chatStore);
const { isMessageDisableForAllUser } = storeToRefs(roomStore);
const editorInputEle = ref();
const sendMsg = ref('');

watch(isMessageDisableByAdmin, (value) => {
  if (value) {
    sendMsg.value = '';
  }
});

watch(isMessageDisableForAllUser, (value) => {
  if (value) {
    sendMsg.value = '';
  }
});
const cannotSendMessage = computed(() => Boolean(isMessageDisableByAdmin.value || isMessageDisableForAllUser.value));
const sendMessage = async () => {
  const msg = sendMsg.value.replace('\n', '');
  sendMsg.value = '';
  if (msg === '') {
    return;
  }
  try {
    await roomEngine.instance?.sendTextMessage({
      messageText: msg,
    });
    chatStore.updateMessageList({
      ID: Math.random().toString(),
      type: 'TIMTextElem',
      payload: {
        text: msg,
      },
      nick: roomStore.localUser.userName || roomStore.localUser.userId,
      from: roomStore.localUser.userId,
      flow: 'out',
      sequence: Math.random(),
    });
  } catch (e) {
    /**
     * Message delivery failure
     *
     * 消息发送失败
    **/
    ElMessage.error(t('Failed to send the message'));
  }
};

const handleChooseEmoji = (emojiName: string) => {
  sendMsg.value += emojiName;
  editorInputEle.value.focus();
};

</script>

<style lang="scss" scoped>
@import '../../assets/style/var.scss';

  .chat-editor {
    height: 188px;
    background: var(--chat-editor-bg-color);
    box-sizing: border-box;
    &.disable-editor {
      textarea {
      }
    }
    textarea {
      height: 138px;
      color: var(--textarea-color);
      width: 100%;
      background: var(--chat-editor-bg-color);
      border: none;
      box-sizing: border-box;
      padding: 12px 14px;
      caret-color: var(--caret-color);
      resize: none;
      &:focus-visible {
        outline: none;
      }
    }
    .send-btn {
      padding: 6px 18px;
      background: var(--send-btn-color);
      border-radius: 2px;
      font-size: 14px;
      color: var(--send-btn);
      &:hover {
        cursor: pointer;
        background: $primaryHighLightColor;
        color: $whiteColor;
      }
      &.active {
        background: $primaryHighLightColor;
        color: $whiteColor;
      }
    }
    .chat-editor-toolbar {
      height: 44px;
      padding: 0 14px 12px;
      display: flex;
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
    }
  }
</style>
