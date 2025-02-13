<template>
  <div
    class="sidebar-container"
  >
    <Drawer
      :model-value="isSidebarOpen"
      :modal="false"
      :title="title"
      direction="rtl"
      :before-close="handleClose"
      :size="480"
    >
      <chat v-if="sidebarName == 'chat'"></chat>
      <room-invite v-if="sidebarName == 'invite'"></room-invite>
      <room-more v-if="sidebarName == 'more'"></room-more>
      <manage-member v-if="sidebarName == 'manage-member'"></manage-member>
    </Drawer>
  </div>
</template>

<script setup lang="ts">
import { useBasicStore } from '../../stores/basic';
import { computed, onUnmounted } from 'vue';
import { storeToRefs } from 'pinia';
import Chat from '../Chat/index.vue';
import RoomInvite from '../RoomInvite/index.vue';
import RoomMore from '../RoomMore/index.vue';
import ManageMember from '../ManageMember/index.vue';
import { useI18n } from '../../locales';
import TUIRoomEngine, { TUIRoomEvents } from '@tencentcloud/tuiroom-engine-js';
import useGetRoomEngine from '../../hooks/useRoomEngine';
import { useChatStore } from '../../stores/chat';
import Drawer from '../../elementComp/Drawer.vue';

const { t } = useI18n();
const roomEngine = useGetRoomEngine();

const chatStore = useChatStore();
const basicStore = useBasicStore();
const { isSidebarOpen, sidebarName } = storeToRefs(basicStore);

const title = computed((): string | undefined => {
  if (sidebarName.value === 'chat') {
    return t('Chat');
  }
  if (sidebarName.value === 'invite') {
    return t('Invite');
  }
  if (sidebarName.value === 'more') {
    return t('Contact us');
  }
  if (sidebarName.value === 'manage-member') {
    return t('Member management');
  }
  return '';
});

function handleClose(done: any) {
  basicStore.setSidebarOpenStatus(false);
  basicStore.setSidebarName('');
  done();
}

/** 监听消息接收，放在这里是为了打开 chat 之前只记录消息未读数 */
const onReceiveTextMessage = (data: { roomId: string, message: any }) => {
  console.warn('onReceiveTextMessage:', data);
  if (!basicStore.isSidebarOpen || basicStore.sidebarName !== 'chat') {
    // eslint-disable-next-line no-plusplus
    chatStore.updateUnReadCount(++chatStore.unReadCount);
  }
};


TUIRoomEngine.once('ready', () => {
  roomEngine.instance?.on(TUIRoomEvents.onReceiveTextMessage, onReceiveTextMessage);
});

onUnmounted(() => {
  roomEngine.instance?.off(TUIRoomEvents.onReceiveTextMessage, onReceiveTextMessage);
});
</script>

<style lang="scss">
@import '../../assets/style/element-custom.scss';

  .sidebar-container > div {
    inset: inherit !important;
    width: 480px !important;
    right: 0 !important;
    top: 0 !important;
    height: 100%;
    position: absolute !important;
  }
  .sidebar-container .el-drawer__header {
    height: 88px;
    border-bottom: 1px solid var(--el-drawer-divide);
    box-sizing: border-box;
    margin-bottom: 0;
    font-size: 20px;
    color: var(--el-drawer-header-color);
    font-weight: 500;
    padding: 32px 22px 32px 32px;
    box-shadow: 0 1px 0 0 var(--divide-line-color);
  }
  .sidebar-container .el-drawer__body {
    padding: 0;
  }
</style>
